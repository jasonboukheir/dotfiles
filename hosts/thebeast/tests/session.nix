{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-session";

  nodes.machine = {...}: {
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
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    gamingUser = cfg.gaming.user;
    devUser = "jasonbk";
    sessionsRoot = "${cfg.services.displayManager.sessionData.desktops}/share";
    defaultDesktopSession = cfg.gaming.defaultDesktopSession;
    gamerDesktopDir = "/home/${gamingUser}/Desktop";
  in ''
    import configparser

    GAMING_USER = "${gamingUser}"
    DEV_USER = "${devUser}"
    SESSIONS_ROOT = "${sessionsRoot}"
    DEFAULT_DESKTOP_SESSION = "${defaultDesktopSession}"
    GAMER_DESKTOP_DIR = "${gamerDesktopDir}"

    def read_sddm_conf():
        """Read the merged sddm config.

        sddm walks /etc/sddm.conf.d/*.conf in lexical order (after an
        optional /etc/sddm.conf, which NixOS does not write); later
        definitions win. ConfigParser with multiple read()s produces
        the same last-wins semantics.
        """
        # ConfigParser.optionxform lowercases keys by default; the
        # canonical keys (User, Session, Relogin, DefaultSession)
        # survive as their lower-case forms. We compare against
        # lowercase below so we don't need to override optionxform —
        # the test driver's type checker rejects the standard
        # `parser.optionxform = str` idiom.
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
        # The host flipped back to SDDM for the UWSM path (#48 plan);
        # verify display-manager.service actually execs sddm and that
        # plasma-login-manager is fully disabled (no plasmalogin config
        # tree).
        dm_unit = machine.succeed(
            "systemctl cat display-manager.service"
        )
        assert "sddm" in dm_unit, \
            f"display-manager.service should exec sddm:\n{dm_unit}"
        status, _ = machine.execute("test -e /etc/plasmalogin.conf.d")
        assert status != 0, (
            "plasma-login-manager should be disabled when sddm is "
            "the active DM; /etc/plasmalogin.conf.d still exists"
        )

    with subtest("autologin honours the standard displayManager contract"):
        # Both DMs read services.displayManager.autoLogin; the sddm
        # module writes the [Autologin] section into 00-nixos.conf.
        # Jovian sets the user/session via the same contract, so the
        # assertion is the same regardless of DM choice.
        sddm_conf = read_sddm_conf()
        assert sddm_conf.has_section("Autologin"), \
            f"sddm config missing [Autologin]:\n{dict(sddm_conf)}"
        autologin = dict(sddm_conf["Autologin"])
        # Keys lowercased by ConfigParser (see read_sddm_conf comment).
        assert autologin.get("user") == GAMING_USER, \
            f"autologin user should be {GAMING_USER}: {autologin}"
        assert autologin.get("session") == "gamescope-wayland.desktop", (
            f"autologin session should be gamescope-wayland; got {autologin}"
        )
        # gaming.exitToGreeter forces Relogin off against jovian's plain
        # `relogin = true` assignment: exiting any session (including
        # Steam's Switch-to-Desktop) must land on the greeter so jasonbk
        # can pick the Hyprland session. If jovian's assignment ever
        # outranks the mkForce, this silently reverts to SteamOS-style
        # re-autologin — the rendered conf is the contract.
        assert autologin.get("relogin") == "false", (
            f"gaming.exitToGreeter should force relogin off: {autologin}"
        )

    with subtest("greeter preselects Hyprland"):
        # SDDM's [General].DefaultSession preselects the greeter's
        # session dropdown. The thebeast.greeterDefaultSession option
        # drives this so jasonbk lands on Hyprland when the greeter
        # appears — which with gaming.exitToGreeter is after every
        # session exit, including leaving Steam.
        sddm_conf = read_sddm_conf()
        preselect = sddm_conf.get("General", "defaultsession", fallback="")
        assert preselect.endswith("hyprland.desktop"), (
            "[General].DefaultSession should be hyprland.desktop; "
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

    with subtest("logind tears down abandoned session scopes (regression for #32)"):
        # The bug: pam_kwallet5 forks ksecretd during pam_sm_open_session,
        # the daemon is re-parented to PID 1 but stays inside the session
        # scope, and with the systemd default KillUserProcesses=no the
        # scope is "abandoned" rather than torn down once Hyprland exits.
        # The orphaned ksecretd then pins the cgroup until reboot.
        #
        # Reproducing pam_kwallet5 in a headless VM is not practical, but
        # the load-bearing behaviour is generic: any process pam left
        # behind in the scope after the session leader exits. A detached
        # `sleep` started inside a real PAM session has the same shape.
        # systemd accepts both `true` and `yes` for boolean directives;
        # nixpkgs' settings-based renderer emits the lower-case bool, so
        # match either spelling to stay robust against a future renderer
        # change.
        logind_conf = machine.succeed("cat /etc/systemd/logind.conf")
        assert any(
            line.replace(" ", "") in {"KillUserProcesses=true", "KillUserProcesses=yes"}
            for line in logind_conf.splitlines()
        ), (
            "logind.conf must enable KillUserProcesses for the #32 fix:\n"
            f"{logind_conf}"
        )

        # Open a real PAM session for jasonbk via machinectl, spawn a
        # detached child that outlives the session leader, then let the
        # leader exit. With KillUserProcesses=yes logind SIGTERMs the
        # whole scope; without it the orphaned child survives.
        machine.succeed(
            f"machinectl shell {DEV_USER}@ /run/current-system/sw/bin/bash -c "
            "'setsid -f sleep 600 </dev/null >/dev/null 2>&1'"
        )

        # logind's scope teardown is asynchronous — give it a generous
        # window before declaring a leak. Pin the pgrep to the canary
        # argv so we don't collide with any unrelated sleep on the box.
        machine.wait_until_fails(
            f"pgrep -u {DEV_USER} -af 'sleep 600' >/dev/null",
            timeout=30,
        )
        leftover_scopes = machine.succeed(
            "systemctl list-units --type=scope --state=abandoned "
            "--no-legend --plain 2>/dev/null || true"
        ).strip()
        assert "session-" not in leftover_scopes, (
            "no session-*.scope should be left abandoned after a clean "
            f"PAM session exit; got:\n{leftover_scopes}"
        )

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
        # /etc/sddm.conf.d/steamos.conf is the is_session_managed()
        # marker steamos-manager probes before exposing the
        # SessionManagement1 interface — without it Switch-to-Desktop
        # never even appears. Jovian writes it whenever autoStart is on.
        machine.succeed("test -e /etc/sddm.conf.d/steamos.conf")

    with subtest("switch-to-big-picture: installed, surfaced, unprivileged"):
        # Plasma's desktop shortcut lives in gamer's ~/Desktop and must
        # resolve to a live store path. A dangling symlink (a previous
        # closure GC'd) silently drops the icon. The .desktop entry and
        # its referenced script are deliberately NOT in
        # /run/current-system/sw — see big-picture.nix for the security
        # rationale — so the gamer desktop symlink is the canonical
        # entry point everything else has to be derived from.
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-big-picture.desktop")
        desktop_target = machine.succeed(
            f"readlink -f {GAMER_DESKTOP_DIR}/switch-to-big-picture.desktop"
        ).strip()
        machine.succeed(f"test -e {desktop_target}")

        # The wrapper must actually shut Steam down before relaunching —
        # otherwise the existing window keeps the single-instance lock
        # and `steam -gamepadui` no-ops back into the same window. Both
        # the shutdown call and the gamepadui exec must appear in the
        # rendered script, which the .desktop entry points to via Exec=.
        desktop_entry = machine.succeed(f"cat {desktop_target}")
        exec_path = next(
            line.split("=", 1)[1].strip()
            for line in desktop_entry.splitlines()
            if line.startswith("Exec=")
        )
        bp_script = machine.succeed(f"cat {exec_path}")
        assert "steam -shutdown" in bp_script, \
            f"big-picture wrapper missing shutdown call:\n{bp_script}"
        assert "steam -gamepadui" in bp_script, \
            f"big-picture wrapper missing gamepadui launch:\n{bp_script}"

        # The wrapper must NOT escalate (no sudo). Real Steam fails in
        # the headless VM (no display, no session bus) so the wrapper's
        # `exec steam -gamepadui` exits non-zero — that's expected and
        # tells us we got past the in-process branches. What we're
        # ruling out is silently routing through a privileged path.
        status, output = machine.execute(
            f"sudo -u {GAMING_USER} {exec_path} 2>&1"
        )
        assert status != 0, \
            f"big-picture wrapper unexpectedly succeeded headless: {output!r}"
        assert "a password is required" not in output and "sudo:" not in output, \
            f"big-picture wrapper must not call sudo: {output!r}"

  '';
}
# Plymouth + boot.kernelParams live in ../boot.nix, which this
# session-scoped test deliberately does not import (the VM stubs hardware
# and skips the host boot layer entirely). The toplevel build is the
# assertion that those land; no separate subtest is meaningful here.

