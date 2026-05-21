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

    def read_plasmalogin_conf():
        """Read the merged plasma-login-manager config.

        plasmalogin walks /etc/plasmalogin.conf.d/*.conf in lexical
        order; later definitions win. ConfigParser with multiple read()s
        produces the same last-wins semantics.
        """
        # ConfigParser.optionxform lowercases keys by default; the
        # canonical keys (User, Session, Relogin, PreselectedSession)
        # survive as their lower-case forms. We compare against
        # lowercase below so we don't need to override optionxform —
        # the test driver's type checker rejects the standard
        # `parser.optionxform = str` idiom.
        parser = configparser.RawConfigParser()
        files = sorted(
            machine.succeed(
                "find /etc/plasmalogin.conf.d -maxdepth 1 -name '*.conf' "
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

    with subtest("display-manager is plasma-login-manager, not sddm or greetd"):
        # The host opted into KDE's new SDDM replacement; verify
        # display-manager.service actually runs plasmalogin and that
        # SDDM is fully disabled (sddm.conf must not exist).
        dm_unit = machine.succeed(
            "systemctl cat display-manager.service"
        )
        assert "plasmalogin" in dm_unit, \
            f"display-manager.service should run plasmalogin:\n{dm_unit}"
        status, _ = machine.execute("test -e /etc/sddm.conf")
        assert status != 0, (
            "SDDM should be disabled when plasma-login-manager is "
            "the active DM; /etc/sddm.conf still exists"
        )

    with subtest("autologin honours the standard displayManager contract"):
        # Both DMs read services.displayManager.autoLogin; plasma-login-manager
        # writes the [Autologin] section into 00-nixos-defaults.conf. Jovian
        # sets the user/session via the same contract, so the assertion is the
        # same regardless of DM choice.
        plasmalogin = read_plasmalogin_conf()
        assert plasmalogin.has_section("Autologin"), \
            f"plasmalogin config missing [Autologin]:\n{dict(plasmalogin)}"
        autologin = dict(plasmalogin["Autologin"])
        # Keys lowercased by ConfigParser (see read_plasmalogin_conf comment).
        assert autologin.get("user") == GAMING_USER, \
            f"autologin user should be {GAMING_USER}: {autologin}"
        assert autologin.get("session") == "gamescope-wayland.desktop", (
            f"autologin session should be gamescope-wayland; got {autologin}"
        )

    with subtest("greeter preselects Hyprland"):
        # plasma-login-manager's [Greeter].PreselectedSession is the
        # equivalent of SDDM's [General].DefaultSession. The
        # thebeast.greeterDefaultSession option drives this so jasonbk
        # lands on Hyprland in the session dropdown when the greeter
        # appears (only after explicit gamer→logout).
        plasmalogin = read_plasmalogin_conf()
        preselect = plasmalogin.get("Greeter", "preselectedsession", fallback="")
        assert preselect == "hyprland.desktop", (
            "[Greeter].PreselectedSession should be hyprland.desktop; "
            f"got {preselect!r}"
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
        # /etc/sddm.conf.d/steamos.conf was the SDDM-era marker
        # steamos-manager probed for. Under plasma-login-manager that
        # path is gone and the relevant probe shifts to whatever PLM
        # surfaces — leave it untested here until upstream wires a
        # PLM-equivalent.

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

  '';
}
# Plymouth + boot.kernelParams live in ../configuration.nix, which this
# session-scoped test deliberately does not import (the VM stubs hardware
# and skips configuration entirely). The toplevel build is the assertion
# that those land; no separate subtest is meaningful here.

