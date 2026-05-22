{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-session";

  nodes.machine = {...}: {
    imports = [
      inputs.agenix.nixosModules.default
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
    themeDir = "/run/current-system/sw/share/sddm/themes/thebeast";
  in ''
    import configparser

    GAMING_USER = "${gamingUser}"
    DEV_USER = "${devUser}"
    SESSIONS_ROOT = "${sessionsRoot}"
    DEFAULT_DESKTOP_SESSION = "${defaultDesktopSession}"
    APPS_DIR = "${appsDir}"
    GAMER_DESKTOP_DIR = "${gamerDesktopDir}"
    THEME_DIR = "${themeDir}"

    def read_sddm_conf():
        """Read the merged SDDM config.

        SDDM walks /etc/sddm.conf.d/*.conf in lexical order, with later
        definitions winning. ConfigParser's multiple read_string()
        calls produce the same last-wins semantics. ConfigParser
        lowercases keys (the test driver's type checker rejects
        `parser.optionxform = str`), so callers compare against
        lowercased section/key names.
        """
        parser = configparser.RawConfigParser()
        files = sorted(
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

    with subtest("display-manager is sddm, not plasma-login-manager or greetd"):
        # The host runs SDDM (the swap back from plasma-login-manager
        # happened in e9318b4 because PLM has no Autologin.Relogin
        # knob). Verify display-manager.service is sddm and that
        # PLM's drop-in dir doesn't exist.
        dm_unit = machine.succeed(
            "systemctl cat display-manager.service"
        )
        assert "sddm" in dm_unit, \
            f"display-manager.service should run sddm:\n{dm_unit}"
        status, _ = machine.execute("test -d /etc/plasmalogin.conf.d")
        assert status != 0, (
            "plasma-login-manager should be disabled when SDDM is "
            "the active DM; /etc/plasmalogin.conf.d still exists"
        )

    with subtest("autologin honours the standard displayManager contract"):
        # SDDM reads [Autologin] from sddm.conf.d/*.conf; jovian's
        # autoStart wiring sets the user/session via the standard
        # services.displayManager.autoLogin contract.
        sddm = read_sddm_conf()
        assert sddm.has_section("Autologin"), \
            f"sddm config missing [Autologin]:\n{dict(sddm)}"
        autologin = dict(sddm["Autologin"])
        # Keys lowercased by ConfigParser (see read_sddm_conf comment).
        assert autologin.get("user") == GAMING_USER, \
            f"autologin user should be {GAMING_USER}: {autologin}"
        assert autologin.get("session") == "gamescope-wayland.desktop", (
            f"autologin session should be gamescope-wayland; got {autologin}"
        )

    with subtest("greeter preselects Hyprland"):
        # [General].DefaultSession is the dropdown's initial selection
        # when the greeter appears (only after explicit gamer→logout,
        # since gamer is autoLogin'd into gamescope-wayland).
        sddm = read_sddm_conf()
        preselect = sddm.get("General", "defaultsession", fallback="")
        assert preselect == "hyprland.desktop", (
            "[General].DefaultSession should be hyprland.desktop; "
            f"got {preselect!r}"
        )

    with subtest("greeter uses the thebeast theme"):
        # The custom theme is what implements per-user session
        # filtering. If [Theme] Current isn't `thebeast`, the filter
        # silently disappears and every user sees every session again.
        sddm = read_sddm_conf()
        theme = sddm.get("Theme", "current", fallback="")
        assert theme == "thebeast", (
            f"[Theme] Current should be thebeast; got {theme!r}"
        )
        machine.succeed(f"test -f {THEME_DIR}/Main.qml")
        machine.succeed(f"test -f {THEME_DIR}/metadata.desktop")

    with subtest("theme.conf maps users to their allowed sessions"):
        # Main.qml's rebuildFilter() reads sessions_<user> from
        # theme.conf. The values are semicolon-separated session
        # basenames (no `.desktop` suffix). A missing or empty value
        # is the "show all sessions" fallback, which is wrong for
        # the two users this host actually configures.
        theme_conf = configparser.RawConfigParser()
        theme_conf.read_string(machine.succeed(f"cat {THEME_DIR}/theme.conf"))
        jasonbk_sessions = theme_conf.get(
            "General", f"sessions_{DEV_USER}", fallback=""
        ).split(";")
        gamer_sessions = theme_conf.get(
            "General", f"sessions_{GAMING_USER}", fallback=""
        ).split(";")
        assert jasonbk_sessions == ["hyprland"], (
            f"{DEV_USER} should see only hyprland; got {jasonbk_sessions}"
        )
        assert sorted(gamer_sessions) == sorted(["plasma", "gamescope-wayland"]), (
            f"{GAMING_USER} should see plasma + gamescope-wayland; got {gamer_sessions}"
        )

    with subtest("session files for all entry points stay installed globally"):
        # Per-user filtering happens at the greeter level; the session
        # files themselves must stay on disk so `steamosctl
        # set-default-desktop-session`, autoLogin.Session, and jovian's
        # gamescope handoff keep resolving. hyprland-uwsm.desktop is
        # specifically here to verify the old package-level filter in
        # modules/omarchy/programs.nix has been removed — a regression
        # would surface as this file vanishing.
        for sess in (
            "gamescope-wayland.desktop",
            f"{DEFAULT_DESKTOP_SESSION}.desktop",
            "hyprland.desktop",
            "hyprland-uwsm.desktop",
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

