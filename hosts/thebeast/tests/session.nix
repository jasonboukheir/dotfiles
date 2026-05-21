{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-session";

  nodes.machine = {...}: {
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      inputs.stylix-nixos-unstable.nixosModules.stylix
      inputs.jovian.nixosModules.default

      ../software.nix
      ../session.nix
      ./test-overrides.nix
    ];
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    gamingUser = cfg.gaming.user;
    devUser = "jasonbk";
    sessionsRoot = "${cfg.services.displayManager.sessionData.desktops}/share";
    defaultDesktopSession = cfg.gaming.defaultDesktopSession;
    appsDir = "/run/current-system/sw/share/applications";
    gamerDesktopDir = "/home/${gamingUser}/Desktop";
  in ''
    import configparser

    GAMING_USER = "${gamingUser}"
    DEV_USER = "${devUser}"
    SESSIONS_ROOT = "${sessionsRoot}"
    DEFAULT_DESKTOP_SESSION = "${defaultDesktopSession}"
    APPS_DIR = "${appsDir}"
    GAMER_DESKTOP_DIR = "${gamerDesktopDir}"

    def read_sddm_conf():
        """Read the merged SDDM config the way SDDM itself would.

        SDDM walks /etc/sddm.conf and /etc/sddm.conf.d/*.conf in lexical
        order; later definitions win. ConfigParser with multiple read()s
        produces the same last-wins semantics.
        """
        # ConfigParser.optionxform lowercases keys by default; SDDM's
        # canonical keys (User, Session, Relogin) survive as their lower-
        # case forms. We compare against lowercase below so we don't
        # need to override optionxform — the test driver's type checker
        # rejects the standard `parser.optionxform = str` idiom.
        parser = configparser.RawConfigParser()
        files = ["/etc/sddm.conf"] + sorted(
            machine.succeed(
                "find /etc/sddm.conf.d -maxdepth 1 -name '*.conf' "
                "-printf '%p\\n' 2>/dev/null || true"
            ).split()
        )
        for path in files:
            status, _ = machine.execute(f"test -r {path}")
            if status != 0:
                continue
            contents = machine.succeed(f"cat {path}")
            parser.read_string(contents)
        return parser

    machine.wait_for_unit("multi-user.target")

    with subtest("specialisations and the old swap apparatus are gone"):
        # The whole point of the refactor — verify the new toplevel has
        # no specialisation children and the runtime-swap wrappers are
        # entirely absent from PATH and from /etc. NixOS always creates
        # the `specialisation` dir; the regression signal is the dir
        # being non-empty.
        children = machine.succeed(
            "ls -1 /run/current-system/specialisation 2>/dev/null || true"
        ).split()
        assert not children, (
            "the single-toplevel design should ship no specialisations; "
            f"found: {children}"
        )
        for binary in (
            "switch-to-game-mode",
            "switch-to-dev-mode",
            "switch-to-game-mode-user",
            "switch-to-dev-mode-user",
            "thebeast-gamer-session",
            "tuigreet",
        ):
            status, _ = machine.execute(f"command -v {binary}")
            assert status != 0, \
                f"{binary} should not be on PATH after the refactor"
        for path in (
            "/etc/thebeast-spec",
            "/etc/systemd/system/greetd.service",
        ):
            status, _ = machine.execute(f"test -e {path}")
            assert status != 0, f"{path} should not exist after the refactor"

    with subtest("display-manager is SDDM (wayland), not greetd"):
        # newer services.displayManager framework: display-manager.service
        # is its own unit that ExecStart's sddm. Confirm by reading the
        # rendered unit (not by following the symlink target, which was
        # the greetd-era alias contract).
        dm_unit = machine.succeed(
            "systemctl cat display-manager.service"
        )
        assert "/sddm" in dm_unit, \
            f"display-manager.service should run sddm:\n{dm_unit}"
        sddm = read_sddm_conf()
        assert sddm.has_section("General"), \
            f"sddm config missing [General]:\n{dict(sddm)}"
        # DisplayServer=wayland is jovian's setting; confirms autoStart
        # wiring landed.
        # Lowercased key — see read_sddm_conf comment.
        assert sddm.get("General", "displayserver", fallback="") == "wayland", (
            "SDDM should be configured for wayland (jovian autoStart contract); "
            f"got {dict(sddm['General'])}"
        )

    with subtest("SDDM autologin: gamer + gamescope, Relogin=false"):
        sddm = read_sddm_conf()
        assert sddm.has_section("Autologin"), \
            f"sddm config missing [Autologin]:\n{dict(sddm)}"
        autologin = dict(sddm["Autologin"])
        # Keys lowercased by ConfigParser (see read_sddm_conf comment).
        assert autologin.get("user") == GAMING_USER, \
            f"SDDM autologin user should be {GAMING_USER}: {autologin}"
        assert autologin.get("session") == "gamescope-wayland.desktop", (
            "SDDM defaultSession should be gamescope-wayland (jovian autoStart); "
            f"got {autologin}"
        )
        # The headline tradeoff in the issue: jovian sets Relogin=true via
        # plain assignment; we mkForce it to false so logout reaches the
        # greeter instead of relogin'ing gamer. If a jovian bump tightens
        # to mkForce true the assert fires and we know to revisit the
        # override.
        relogin = autologin.get("relogin", "true").lower()
        assert relogin == "false", (
            "services.displayManager.sddm.autoLogin.relogin = mkForce false "
            f"did not stick; rendered SDDM config has Relogin={relogin!r}"
        )

    with subtest("session files for all three entry points exist"):
        # gamescope-wayland: jovian default, runs on first boot.
        # plasma: the Switch-to-Desktop target.
        # hyprland: jasonbk's pick from the greeter.
        for sess in (
            "gamescope-wayland.desktop",
            f"{DEFAULT_DESKTOP_SESSION}.desktop",
            "hyprland.desktop",
        ):
            machine.succeed(f"test -e {SESSIONS_ROOT}/wayland-sessions/{sess}")

    with subtest("both users exist with the right gaming groups"):
        for user in (GAMING_USER, DEV_USER):
            machine.succeed(f"id -nG {user} | grep -qw gamemode")
            machine.succeed(f"id -nG {user} | grep -qw input")

    with subtest("jovian session-side user units are installed"):
        # These are what populate steamos-manager's DefaultDesktopSession
        # and tear down the zzt- SDDM override after a desktop round trip.
        # If either is missing, Switch-to-Desktop falls back to gamescope
        # or leaves a stale temp conf that hijacks the next login.
        for unit in (
            "jovian-setup-desktop-session.service",
            "steamos-manager-session-cleanup.service",
        ):
            machine.succeed(f"test -e /etc/systemd/user/{unit}")
        # jovian-setup-desktop-session passes the configured desktop
        # session to steamosctl; spot-check the rendered command so a
        # silent rename can't slip past.
        rendered = machine.succeed(
            "cat /etc/systemd/user/jovian-setup-desktop-session.service"
        )
        assert f"set-default-desktop-session {DEFAULT_DESKTOP_SESSION}.desktop" in rendered, (
            "jovian-setup-desktop-session should hand "
            f"{DEFAULT_DESKTOP_SESSION}.desktop to steamosctl; got:\n{rendered}"
        )
        # Marker the steamos-manager probes to decide whether session
        # management is offered.
        machine.succeed("test -e /etc/sddm.conf.d/steamos.conf")

    with subtest("switch-to-big-picture: installed, surfaced, unprivileged"):
        # The wrapper must actually shut Steam down before relaunching —
        # otherwise the existing window keeps the single-instance lock
        # and `steam -gamepadui` no-ops back into the same window. Both
        # the shutdown call and the gamepadui exec must appear in the
        # rendered script.
        machine.succeed(f"test -e {APPS_DIR}/switch-to-big-picture.desktop")
        bp_script = machine.succeed("cat $(command -v switch-to-big-picture)")
        assert "steam -shutdown" in bp_script, \
            f"big-picture wrapper missing shutdown call:\n{bp_script}"
        assert "steam -gamepadui" in bp_script, \
            f"big-picture wrapper missing gamepadui launch:\n{bp_script}"
        # Plasma's desktop shortcut lives in gamer's ~/Desktop and must
        # resolve to a live store path. A dangling symlink (a previous
        # closure GC'd) silently drops the icon.
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-big-picture.desktop")
        target = machine.succeed(
            f"readlink -f {GAMER_DESKTOP_DIR}/switch-to-big-picture.desktop"
        ).strip()
        machine.succeed(f"test -e {target}")

        # The wrapper must NOT escalate (no sudo). Real Steam fails in
        # the headless VM (no display, no session bus) so the wrapper's
        # `exec steam -gamepadui` exits non-zero — that's expected and
        # tells us we got past the in-process branches. What we're
        # ruling out is silently routing through a privileged path.
        status, output = machine.execute(
            f"sudo -u {GAMING_USER} switch-to-big-picture 2>&1"
        )
        assert status != 0, \
            f"big-picture wrapper unexpectedly succeeded headless: {output!r}"
        assert "a password is required" not in output and "sudo:" not in output, \
            f"big-picture wrapper must not call sudo: {output!r}"

    with subtest("plymouth + quiet/splash were dropped with the swap UX"):
        # Plymouth existed to paint diagnostic text while the spec swap
        # drained session scopes. With no swap there's no reason to ship
        # it; verify the obvious surfaces went away.
        cmdline = machine.succeed("cat /proc/cmdline")
        # The kernel cmdline in the VM doesn't include host params
        # verbatim, but `quiet splash` would only land if kernelParams
        # set it. Sample with a tolerance check: neither should appear.
        assert "splash" not in cmdline.split(), (
            f"boot.kernelParams should no longer include splash:\n{cmdline}"
        )
        # plymouth.enable would install /etc/plymouth/plymouthd.conf
        # and the plymouth-start.service. Missing both is the signal
        # that boot.plymouth.enable is false.
        status, _ = machine.execute("test -e /etc/plymouth/plymouthd.conf")
        assert status != 0, "boot.plymouth was supposed to be removed"
  '';
}
