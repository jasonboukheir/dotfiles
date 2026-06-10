# Wrapper plumbing: my.mako.settings -> baked --config -> wrapped mako, through
# both launch paths (direct exec, as the omarchy systemd unit does, and dbus
# activation via the corrected fr.emersion.mako.service).
{
  pkgs,
  inputs ? null,
}: let
  pkgsWrapped = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
  sentinel = "/tmp/mako-on-notify";

  hasNotificationsOwner = ''dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner string:org.freedesktop.Notifications | grep -q 'boolean true' '';

  sessionScript = pkgs.writeShellScript "mako-test-session" ''
    (
      set -ex
      export PATH="/etc/profiles/per-user/tester/bin:$PATH"
      dbus-update-activation-environment --all

      mako &
      mako_pid=$!
      for _ in $(seq 50); do ${hasNotificationsOwner} && break; sleep 0.2; done
      notify-send direct-summary direct-body
      for _ in $(seq 50); do [ -e ${sentinel} ] && break; sleep 0.2; done
      makoctl list > /tmp/direct-list.json
      mv ${sentinel} ${sentinel}-direct
      kill "$mako_pid"
      wait "$mako_pid" || true
      for _ in $(seq 50); do ${hasNotificationsOwner} || break; sleep 0.2; done

      notify-send activated-summary activated-body
      for _ in $(seq 50); do [ -e ${sentinel} ] && break; sleep 0.2; done
      makoctl list > /tmp/activated-list.json
      mv ${sentinel} ${sentinel}-activated
    ) > /tmp/session-log 2>&1
    echo $? > /tmp/session-status
    swaymsg exit
  '';

  swayConfig = pkgs.writeText "sway-test-config" ''
    xwayland disable
    exec ${sessionScript}
  '';
in
  pkgs.testers.nixosTest {
    name = "my-mako-wrapper";

    nodes.machine = {
      nixpkgs.pkgs = pkgsWrapped;
      imports = [../nixos.nix];

      environment.systemPackages = [pkgs.sway pkgs.libnotify pkgs.dbus];
      fonts.packages = [pkgs.dejavu_fonts];

      users.users.tester = {
        isNormalUser = true;
        my.mako.enable = true;
        my.mako.settings = {
          default-timeout = 0;
          max-visible = 7;
          on-notify = "exec touch ${sentinel}";
        };
      };
    };

    testScript = ''
      machine.wait_for_unit("multi-user.target")

      profile = "/etc/profiles/per-user/tester"

      with subtest("the wrapper bakes the rendered settings via --config"):
          machine.succeed(f"grep -q -- '--config' $(readlink -f {profile}/bin/mako)")
          config_path = machine.succeed(
              f"grep -o '/nix/store/[^\" ]*-mako-config' $(readlink -f {profile}/bin/mako) | head -n1"
          ).strip()
          baked = machine.succeed(f"cat {config_path}")
          assert "max-visible=7" in baked, f"baked config missing sentinel setting: {baked!r}"

      with subtest("shipped activation files are rewritten to the wrapped binary"):
          for service in [
              "share/dbus-1/services/fr.emersion.mako.service",
              "share/systemd/user/mako.service",
              "lib/systemd/user/mako.service",
          ]:
              execs = machine.succeed(f"grep '^Exec.*bin/mako' {profile}/{service}")
              for line in execs.strip().splitlines():
                  assert "mako-wrapped" in line, f"{service} still points at the unwrapped package: {line!r}"

      with subtest("a headless sway session exercises both launch paths"):
          machine.succeed("install -d -m 700 -o tester -g users /tmp/xdg")
          machine.succeed(
              "timeout 180 su -l tester -c '"
              "env XDG_RUNTIME_DIR=/tmp/xdg"
              " XDG_DATA_DIRS=/etc/profiles/per-user/tester/share:/run/current-system/sw/share"
              " WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman"
              " dbus-run-session -- sway -c ${swayConfig}'"
          )
          status = machine.succeed("cat /tmp/session-status").strip()
          session_log = machine.succeed("cat /tmp/session-log")
          assert status == "0", f"session script failed:\n{session_log}"

      with subtest("directly launched wrapped mako loaded the baked config (on-notify fired)"):
          machine.succeed("test -e ${sentinel}-direct")
          direct = machine.succeed("cat /tmp/direct-list.json")
          assert "direct-summary" in direct, f"notification missing from makoctl list: {direct!r}"

      with subtest("dbus activation spawns the wrapper, not the unwrapped binary"):
          machine.succeed("test -e ${sentinel}-activated")
          activated = machine.succeed("cat /tmp/activated-list.json")
          assert "activated-summary" in activated, f"notification missing from makoctl list: {activated!r}"
    '';
  }
