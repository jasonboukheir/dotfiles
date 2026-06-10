{
  pkgs,
  inputs,
}: let
  # Runs as jasonbk under a private session bus. `gnome-keyring-daemon
  # --login` is exactly what pam_gnome_keyring's auto_start invokes at login:
  # it reads the login password from stdin and unlocks (creating on first
  # use) ~/.local/share/keyrings/login.keyring; --start then publishes the
  # org.freedesktop.secrets component on the bus. We then round-trip a secret
  # through that service with no prompt — a locked keyring would block on an
  # absent prompter, which the caller's `timeout` catches. subtests 2+3 prove
  # the DM's login PAM stack is what fires this same unlock at a real login.
  keyringProbe = pkgs.writeShellScript "keyring-probe" ''
    set -euo pipefail
    exec 2>&1
    eval "$(echo -n test | gnome-keyring-daemon --daemonize --login --components=secrets)"
    export GNOME_KEYRING_CONTROL SSH_AUTH_SOCK
    for _ in $(seq 1 40); do
      busctl --user list 2>/dev/null | grep -q org.freedesktop.secrets && break
      gnome-keyring-daemon --start --components=secrets >/dev/null 2>&1 || true
      sleep 0.5
    done
    printf %s secret-value-42 \
      | secret-tool store --label=nixos-test service nixos-keyring-test
    got=$(secret-tool lookup service nixos-keyring-test)
    echo "probe: got=$got"
    [ "$got" = secret-value-42 ]
    alias=$(busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
      org.freedesktop.Secret.Service ReadAlias s default)
    echo "default-alias=$alias"
    case "$alias" in
      *collection*) : ;;
      *) echo "no default collection (ReadAlias returned $alias)"; exit 3 ;;
    esac
    owner_pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
      org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.secrets \
      | awk '{print $2}')
    comm=$(cat "/proc/$owner_pid/comm")
    echo "secrets-owner=$comm"
    case "$comm" in
      *keyring*) : ;;
      *) echo "org.freedesktop.secrets served by $comm, not gnome-keyring"; exit 4 ;;
    esac
    echo KEYRING_OK
  '';
in
  pkgs.testers.nixosTest {
    name = "thebeast-keyring";

    nodes.machine = {
      lib,
      pkgs,
      ...
    }: {
      _module.args.inputs = inputs;
      imports = [
        inputs.agenix.nixosModules.default
        inputs.home-manager-nixos-unstable.nixosModules.home-manager
        inputs.stylix-nixos-unstable.nixosModules.stylix
        inputs.jovian.nixosModules.default

        ../system
        ../session
        ./test-overrides.nix
      ];

      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };

      # Headless: gamescope autologin can't run and only adds boot noise
      # (with jovian's Relogin=true it would respawn in a loop). The
      # unlock we exercise goes through the `login` PAM stack directly,
      # not the greeter's VT.
      services.displayManager.autoLogin.enable = lib.mkForce false;

      # Give jasonbk a known password so the test can drive a real password
      # login (the stub age secret from test-overrides isn't a valid hash).
      # hashedPasswordFile must be cleared first — the user module rejects
      # both being set.
      users.users.jasonbk.hashedPasswordFile = lib.mkForce null;
      users.users.jasonbk.password = lib.mkForce "test";

      environment.systemPackages = [pkgs.pamtester pkgs.libsecret];
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      with subtest("gnome-keyring is the org.freedesktop.secrets provider, not ksecretd"):
          # Find every activation file claiming the name and inspect what it
          # execs. gnome-keyring must serve it; the ksecretd shim
          # (modules/nixos/programs/kwallet.nix) must be gated off whenever
          # gnome-keyring is enabled. The dir entries are store symlinks, so
          # pass them as a glob (command-line args grep follows) rather than
          # `grep -r`, which skips symlinks found during recursion.
          files = machine.succeed(
              "grep -l 'Name=org.freedesktop.secrets' "
              "/run/current-system/sw/share/dbus-1/services/*.service"
          ).split()
          assert files, "no D-Bus activation file claims org.freedesktop.secrets"
          execs = machine.succeed("grep -h '^Exec=' " + " ".join(files))
          assert "gnome-keyring-daemon" in execs, (
              "org.freedesktop.secrets should exec gnome-keyring-daemon:\n" + execs
          )
          assert "ksecretd" not in execs, (
              "ksecretd shim must not register org.freedesktop.secrets when "
              "gnome-keyring is the provider:\n" + execs
          )

      with subtest("pam_gnome_keyring is wired into the login stack"):
          login_pam = machine.succeed("cat /etc/pam.d/login")
          assert "pam_gnome_keyring.so" in login_pam, (
              "login PAM stack is missing pam_gnome_keyring:\n" + login_pam
          )
          # auto_start on the session line is what unlocks at login.
          assert any(
              "pam_gnome_keyring.so" in ln and "auto_start" in ln
              for ln in login_pam.splitlines()
          ), ("login session stack must auto_start gnome-keyring:\n" + login_pam)

      with subtest("the greeter (sddm) inherits the login stack"):
          # sddm's PAM service lists no keyring modules itself — NixOS
          # renders it as substack/include `login`, so the unlock above
          # applies to a real greeter login. This is the crux of "can the
          # login manager unlock the keyring": the greeter runs the same
          # login stack that the behavioural subtest proves works.
          # (sddm-autologin includes sddm, so gamer's autologin rides the
          # same stack.)
          sddm_pam = machine.succeed("cat /etc/pam.d/sddm")
          assert ("substack login" in sddm_pam) or ("include login" in sddm_pam), (
              "sddm must pull in the login stack:\n" + sddm_pam
          )

      with subtest("a password unlock makes the secret service store & retrieve a secret"):
          # gnome-keyring-daemon --login (what pam_gnome_keyring runs at
          # login) unlocks jasonbk's login keyring with the password, then a
          # secret round-trips through org.freedesktop.secrets with no prompt.
          uid = machine.succeed("id -u jasonbk").strip()
          machine.succeed(
              f"install -d -o jasonbk -g users -m 700 /run/user/{uid}"
          )
          out = machine.succeed(
              "timeout 90 runuser -u jasonbk -- env HOME=/home/jasonbk "
              f"XDG_RUNTIME_DIR=/run/user/{uid} "
              "dbus-run-session -- ${keyringProbe}"
          )
          machine.log(out)
          assert "KEYRING_OK" in out, f"keyring round-trip failed:\n{out}"

      with subtest("the login PAM stack itself unlocks gnome-keyring"):
          # End-to-end check that the *login* path fires the unlock: drive the
          # real `login` PAM stack as root (as a DM does) authenticating
          # jasonbk, and require pam_gnome_keyring to report a successful
          # unlock. (pamtester opens the session but doesn't export the
          # PAM environment into a shell the way a DM does, so the secret
          # round-trip itself is covered by the subtest above.)
          machine.succeed(
              "echo test | pamtester login jasonbk authenticate open_session"
          )
          machine.succeed(
              "journalctl -b | grep -q 'gkr-pam:.*unlocked keyring'"
          )
    '';
  }
