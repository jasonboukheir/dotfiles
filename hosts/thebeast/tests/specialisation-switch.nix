{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "thebeast-specialisation-switch";

  nodes.machine = {...}: {
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      inputs.stylix-nixos-unstable.nixosModules.stylix
      inputs.jovian.nixosModules.default

      ../software.nix
      ../specialisations/gaming
      ../specialisations
      ./test-overrides.nix
    ];

    # An account with no sudo rule, used to assert NOPASSWD doesn't leak
    # the privileged switchers to unauthorized users. Without this we'd
    # only ever assert the positive case.
    users.users.unauth = {
      isNormalUser = true;
      description = "no sudo access — negative permission probe";
    };
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    gamingUser = cfg.gaming.user;
    devUser = "jasonbk";
    sessionsRoot = "${cfg.services.displayManager.sessionData.desktops}/share";
    sessionEntrypointBin = baseNameOf cfg.gaming.sessionEntrypoint;
    appsDir = "/run/current-system/sw/share/applications";
    gamerDesktopDir = "/home/${gamingUser}/Desktop";
    defaultDesktopSession = cfg.gaming.defaultDesktopSession;
  in ''
    import re
    import tomllib

    GAMING_USER = "${gamingUser}"
    DEV_USER = "${devUser}"
    UNAUTH_USER = "unauth"
    SESSIONS_ROOT = "${sessionsRoot}"
    SESSION_ENTRYPOINT_BIN = "${sessionEntrypointBin}"
    APPS_DIR = "${appsDir}"
    GAMER_DESKTOP_DIR = "${gamerDesktopDir}"
    DEFAULT_DESKTOP_SESSION = "${defaultDesktopSession}"

    # switch-to-configuration returns 4 when system activation succeeded
    # but a user-instance reload didn't — typically because the retiring
    # spec's user units are still pointing at the previous toplevel.
    SUCCESS_CODES = (0, 4)

    def run_switch(name):
        status, output = machine.execute(
            f"/run/current-system/sw/bin/switch-to-{name}-mode"
        )
        assert status in SUCCESS_CODES, \
            f"switch-to-{name}-mode exited {status}: {output}"

    def run_user_wrapper(user, direction):
        status, output = machine.execute(
            f"sudo -u {user} /run/current-system/sw/bin/switch-to-{direction}-mode-user"
        )
        assert status in SUCCESS_CODES, \
            f"switch-to-{direction}-mode-user as {user} exited {status}: {output}"
        return output

    def current_spec():
        # The marker is the source of truth the user wrappers branch on.
        # If this drifts from the active toplevel, the dev-mode short-circuit
        # and the steamosctl-vs-sudo dispatch break silently.
        return machine.succeed("cat /etc/thebeast-spec").strip()

    def greetd_config():
        """Parse greetd's TOML config from the unit's --config flag."""
        unit = machine.succeed("cat /etc/systemd/system/greetd.service")
        m = re.search(r"--config\s+(\S+)", unit)
        assert m, f"greetd unit missing --config flag:\n{unit}"
        return tomllib.loads(machine.succeed(f"cat {m.group(1)}"))

    def greetd_enter_ts():
        # ActiveEnterTimestampMonotonic strictly increases on each (re)start;
        # comparing before/after a swap is how we prove greetd actually
        # restarted, not just that the rendered toml changed on disk.
        return int(machine.succeed(
            "systemctl show -p ActiveEnterTimestampMonotonic --value greetd.service"
        ).strip())

    def unit_state(unit):
        return machine.succeed(
            f"systemctl show -p ActiveState --value {unit} 2>/dev/null || echo unknown"
        ).strip()

    def assert_no_sddm():
        machine.fail("pgrep -x sddm")
        dm_target = machine.succeed(
            "readlink -f /etc/systemd/system/display-manager.service"
        ).strip()
        assert dm_target.endswith("/greetd.service"), \
            f"display-manager.service should alias greetd, got {dm_target}"

    def assert_gaming_active():
        assert current_spec() == "gaming", \
            f"expected gaming spec, got {current_spec()!r}"
        config = greetd_config()
        initial = config.get("initial_session")
        assert initial is not None, \
            f"gaming greetd missing initial_session: {config}"
        assert initial.get("user") == GAMING_USER, \
            f"gaming initial_session must autologin {GAMING_USER}: {initial}"
        # Substring catches a regression where greetd.nix stops sourcing
        # cfg.sessionEntrypoint and hardcodes a different path; the
        # executable check below catches the inverse (entrypoint missing
        # from the closure). Either alone would be too weak.
        initial_command = initial.get("command", "")
        assert SESSION_ENTRYPOINT_BIN in initial_command, \
            f"gaming initial_session should run {SESSION_ENTRYPOINT_BIN}: {initial}"
        machine.succeed(f"test -x {initial_command.split()[0]}")
        # default_session is what greetd falls back to on logout; for the
        # autologin spec we want it to re-trigger the same flow.
        default = config.get("default_session", {})
        assert SESSION_ENTRYPOINT_BIN in default.get("command", ""), \
            f"gaming default_session should mirror initial_session: {default}"
        # jasonbk picks up the gamemode group only in the gaming toplevel.
        machine.succeed(f"id -nG {DEV_USER} | grep -qw gamemode")
        assert_no_sddm()

    def assert_dev_active():
        assert current_spec() == "dev", \
            f"expected dev spec, got {current_spec()!r}"
        config = greetd_config()
        assert "initial_session" not in config, \
            f"dev greetd should not autologin:\n{config}"
        default = config.get("default_session", {})
        # greetd.nix leaves default_session.user unset and relies on the
        # upstream default of "greeter". Distinguish "unset" (fine — we
        # want the upstream default) from "set to anything else" (a
        # regression that would run the greeter as a privileged user).
        # The pure tautology `default.get("user", "greeter") == "greeter"`
        # can never fail on a missing key — this catches the mis-set case.
        assert "user" not in default or default["user"] == "greeter", \
            f"dev default_session.user must remain unset or 'greeter': {default}"
        # tuigreet running is the behavior; the rendered command string is
        # an implementation detail of greetd.nix that pgrep already covers.
        machine.wait_until_succeeds("pgrep -x tuigreet", timeout=30)
        assert unit_state("greetd.service") == "active", \
            f"greetd state: {unit_state('greetd.service')}"
        assert_no_sddm()
        # If hyprland stops shipping a wayland session file at the path
        # tuigreet was handed, jasonbk lands at a blank greeter. Pull the
        # path from the parsed config and confirm at least one .desktop.
        # Tolerate both `--sessions <arg>` and `--sessions=<arg>` since
        # the separator isn't part of tuigreet's stable contract.
        m = re.search(r"--sessions[=\s]+(\S+)", default["command"])
        assert m, f"tuigreet command missing --sessions: {default['command']}"
        sessions = machine.succeed(f"ls {m.group(1)}").split()
        assert any(s.endswith(".desktop") for s in sessions), \
            f"tuigreet sessions dir should contain a .desktop: {sessions}"

    def running_services():
        units = set(machine.succeed(
            "systemctl list-units --type=service --state=running "
            "--no-legend --plain | awk '{print $1}'"
        ).split())
        # Per-user transient units come and go with sudo and login sessions.
        return {u for u in units if not u.startswith("user@")}

    machine.wait_for_unit("multi-user.target")

    with subtest("base config is gaming with greetd autologin"):
        machine.wait_for_unit("display-manager.service")
        assert_gaming_active()
        machine.succeed(
            "test -x /run/current-system/specialisation/dev/bin/switch-to-configuration"
        )

    with subtest("swap shortcuts are installed and present on gamer's desktop"):
        for entry in ("switch-to-game-mode.desktop", "switch-to-dev-mode.desktop"):
            machine.succeed(f"test -e {APPS_DIR}/{entry}")
        machine.succeed("command -v switch-to-game-mode-user")
        machine.succeed("command -v switch-to-dev-mode-user")
        # Both directions on gamer's Desktop in either spec — tmpfiles is
        # unconditional so a dev rebuild doesn't leave stale symlinks.
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-dev-mode.desktop")
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-game-mode.desktop")

    with subtest("NOPASSWD sudo rules are installed for both gamer and jasonbk"):
        # Structural check: `sudo -ll` enumerates every rule a user has.
        # We verify both wrapper commands appear under !authenticate
        # (NOPASSWD) for both users. End-to-end behavior is exercised by
        # the user-wrapper tests below; this just confirms the rule
        # itself exists, since a missing rule turns the desktop-shortcut
        # click into a silent password prompt the user can't satisfy.
        #
        # Note: `sudo -ln <cmd>` would test the same thing but matches
        # the user-supplied path verbatim against the rule. Our rule
        # names a /nix/store path; jasonbk's %wheel ALL entry masks that
        # mismatch, but gamer (no wheel) fails the verbatim match. The
        # rule is correct — the testing approach was wrong.
        for user in (DEV_USER, GAMING_USER):
            rules = machine.succeed(f"sudo -u {user} sudo -n -ll")
            assert "!authenticate" in rules, \
                f"{user} missing NOPASSWD entry:\n{rules}"
            assert "switch-to-game-mode" in rules, \
                f"{user} missing switch-to-game-mode rule:\n{rules}"
            assert "switch-to-dev-mode" in rules, \
                f"{user} missing switch-to-dev-mode rule:\n{rules}"
        # An account with no rule at all gets a non-zero exit from sudo -ll.
        status, _ = machine.execute(f"sudo -u {UNAUTH_USER} sudo -n -ll")
        assert status != 0, \
            f"{UNAUTH_USER} unexpectedly has sudo rules"

    with subtest("switch-to-desktop infrastructure is wired in gaming mode"):
        machine.succeed("command -v thebeast-gamer-session")
        # Plasma and gamescope-wayland must both register entries in the
        # aggregated sessions dir — steamos-manager picks Session= from here.
        machine.succeed(
            f"test -e {SESSIONS_ROOT}/wayland-sessions/{DEFAULT_DESKTOP_SESSION}"
        )
        machine.succeed(
            f"test -e {SESSIONS_ROOT}/wayland-sessions/gamescope-wayland.desktop"
        )
        # Marker file telling steamos-manager it may manage sessions here.
        machine.succeed("test -e /etc/sddm.conf.d/steamos.conf")
        # User-instance oneshots that populate DefaultDesktopSession and
        # tear down the temp override after a desktop session settles.
        for unit in (
            "jovian-setup-desktop-session.service",
            "steamos-manager-session-cleanup.service",
        ):
            machine.succeed(f"test -e /etc/systemd/user/{unit}")

    with subtest("steamos-manager system unit + user bus activation"):
        assert unit_state("steamos-manager.service") in ("active", "activating"), \
            f"steamos-manager.service state: {unit_state('steamos-manager.service')}"
        # Session-bus activation file — clicking "Switch to Game Mode" from
        # plasma routes through steamosctl which hits the user instance via
        # this dbus service file. If services.dbus.packages stops carrying
        # steamos-manager, the desktop entry is a silent no-op.
        machine.succeed(
            "find /run/current-system/sw/share/dbus-1 "
            "-name com.steampowered.SteamOSManager1.service | grep -q ."
        )

    with subtest("session wrapper resolves steamos-manager's SDDM temp override"):
        machine.succeed("install -d -m 0755 /etc/sddm.conf.d")
        machine.succeed(
            f"printf '[Autologin]\\nUser={GAMING_USER}\\n"
            f"Session={DEFAULT_DESKTOP_SESSION}\\n' "
            "> /etc/sddm.conf.d/zzt-steamos-temp-login.conf"
        )
        resolved = machine.succeed("thebeast-gamer-session --print-resolved").strip()
        # The Session= override flipped the wrapper away from its gamescope
        # default to whatever plasma.desktop's Exec= names. We don't pin the
        # upstream Plasma binary name (it has been renamed before); instead
        # assert (a) the resolved binary is executable and (b) the override
        # genuinely landed us somewhere other than the gamescope fallback.
        resolved_bin = resolved.split()[0]
        machine.succeed(f"test -x {resolved_bin}")
        assert "gamescope" not in resolved, \
            f"Session=plasma override should not resolve to gamescope: {resolved!r}"

        machine.succeed("rm -f /etc/sddm.conf.d/zzt-steamos-temp-login.conf")
        resolved = machine.succeed("thebeast-gamer-session --print-resolved").strip()
        assert "start-gamescope-session" in resolved, \
            f"wrapper should pick gamescope by default; got: {resolved!r}"
        # XDG single-char field codes must not survive the wrapper —
        # gamescope-wayland.desktop ships `Exec=...gamescope-wayland %F`
        # upstream and `sh -c` would treat the surviving `%F` as an
        # opaque positional argument. Checked on the gamescope branch
        # specifically since plasma.desktop tends not to carry codes.
        for code in ("%f", "%F", "%u", "%U", "%i", "%c", "%k"):
            assert code not in resolved, \
                f"XDG field code {code} leaked past the wrapper: {resolved!r}"

    # Snapshot AFTER the read-only assertions but BEFORE any swaps, so the
    # leak comparison covers all production flips below.
    baseline_units = running_services()

    with subtest("user wrapper as gamer in gaming → escalates, swaps to dev, and reaps the slice"):
        # End-to-end verification of gamer's NOPASSWD rule, in the
        # production direction: gamer is autologin'd in gaming and
        # clicks "Switch to Dev Mode". The wrapper takes the sudo
        # branch, which exercises gamer's per-command rule. Doing this
        # in the gaming→dev direction (not dev→gaming) avoids a logind
        # race: switch-to-dev-mode's swapWrapper retires gamer's
        # cgroup explicitly before switch-to-configuration enumerates
        # users.
        #
        # The headline regression here was that in production gamer's
        # plasma session lives in a session-N.scope under
        # user-<uid>.slice — a *sibling* of user@<uid>.service, not a
        # child. Stopping only user@<uid>.service leaves the plasma
        # session alive, which holds tty1 and prevents the new greetd
        # from spawning tuigreet (the user sees a blinking underscore
        # on tty1 after plasma quits and never gets the dev greeter).
        # Reproduce by parking a unit in the slice that is NOT under
        # user@<uid>.service, and assert the swap kills it.
        uid = machine.succeed(f"id -u {GAMING_USER}").strip()
        machine.succeed(f"loginctl enable-linger {GAMING_USER}")
        machine.succeed(f"systemctl start user@{uid}.service")
        machine.wait_until_succeeds(f"systemctl is-active user@{uid}.service")
        # systemd-run resolves --uid by name and uses the user's
        # primary group automatically; passing a numeric --gid risks
        # a UID/GID mismatch we hit on this host (gamer's GID != UID).
        machine.succeed(
            f"systemd-run --uid={GAMING_USER} "
            f"--slice=user-{uid}.slice --unit=fake-plasma "
            f"--no-block -- sleep 600"
        )
        machine.wait_until_succeeds("systemctl is-active fake-plasma.service")

        before = greetd_enter_ts()
        run_user_wrapper(GAMING_USER, "dev")
        assert_dev_active()
        after = greetd_enter_ts()
        assert after > before, \
            f"gamer's NOPASSWD escalation should restart greetd: {before} -> {after}"

        # The swap must have torn down everything in gamer's slice —
        # the transient (mimicking a session scope) AND the user
        # manager. `is-active --quiet` exits 0 only when the unit is
        # active, so a non-zero exit covers every "reaped" state
        # (inactive, failed, gone) without parsing the printed line.
        fake_status, _ = machine.execute(
            "systemctl is-active --quiet fake-plasma.service"
        )
        assert fake_status != 0, \
            "fake-plasma should be reaped by the swap but is still active"
        slice_status, _ = machine.execute(
            f"systemctl is-active --quiet user-{uid}.slice"
        )
        assert slice_status != 0, \
            f"user-{uid}.slice should be inactive after swap but is still active"
        # No leftover processes owned by gamer. ps -u prints nothing on
        # success (no headers, no rows) when the user has no procs.
        survivors = machine.succeed(
            f"ps -o pid,comm --no-headers -u {GAMING_USER} 2>/dev/null || true"
        ).strip()
        assert not survivors, \
            f"gamer-owned processes survived the swap: {survivors!r}"

    with subtest("user wrapper short-circuits when already in dev"):
        before = greetd_enter_ts()
        out = machine.succeed(
            f"sudo -u {DEV_USER} /run/current-system/sw/bin/switch-to-dev-mode-user 2>&1"
        )
        assert "Already in dev mode" in out, \
            f"dev-mode-user should short-circuit in dev: {out!r}"
        assert current_spec() == "dev", \
            "short-circuit must not change the live spec"
        # No greetd restart means no switch-to-configuration ran.
        after = greetd_enter_ts()
        assert after == before, \
            f"short-circuit should leave greetd untouched: {before} -> {after}"

    with subtest("unauthorized user cannot escalate via the user wrapper"):
        # Still in dev — the wrapper takes the sudo branch here. The
        # unauth user has no NOPASSWD rule, so sudo -n exits non-zero
        # and the wrapper propagates that. This is the negative path the
        # static permission check above can't prove on its own.
        #
        # Capturing combined output and matching sudo's denial phrasing
        # ("a password is required" for sudo -n) is the difference between
        # "wrapper failed for *some* reason" (e.g. a typo'd binary path)
        # and "wrapper failed *because* the sudo policy refused us". The
        # weaker `status != 0` check would silently pass on regressions
        # that break the wrapper for every user.
        status, output = machine.execute(
            f"sudo -u {UNAUTH_USER} /run/current-system/sw/bin/switch-to-game-mode-user 2>&1"
        )
        assert status != 0, \
            f"unauth user should not be able to swap specs: status={status} output={output!r}"
        assert "a password is required" in output, \
            f"failure must come from sudo policy, not the wrapper itself: {output!r}"
        assert current_spec() == "dev", \
            "denied escalation must not have flipped the spec"

    with subtest("user wrapper as jasonbk in dev → escalates and swaps to gaming"):
        # Production codepath for the back-half of the swap. Covers the
        # headline detection bug from the other direction: readlink-based
        # detection used to fall through to a no-op here.
        before = greetd_enter_ts()
        run_user_wrapper(DEV_USER, "game")
        assert_gaming_active()
        after = greetd_enter_ts()
        assert after > before, \
            f"greetd must restart across spec swap: {before} -> {after}"

    with subtest("gamer in gaming → game-mode-user dispatches to steamosctl"):
        # In the steamosctl branch the wrapper must NOT escalate, AND it
        # must actually `exec steamosctl`. The earlier version of this
        # test only asserted "greetd didn't restart + spec is still
        # gaming" — both of which a `case "$spec" in *) exit 0 ;; esac`
        # regression would also satisfy.
        #
        # Three signals together pin the dispatch:
        #   1. Real steamosctl fails non-zero in the headless VM (no
        #      DBus session bus), so status == 0 is the deleted-arm
        #      regression and we reject it.
        #   2. sudo's NOPASSWD denial would produce "a password is
        #      required" / "sudo:" — its absence rules out a wrong-branch
        #      regression.
        #   3. Unit timestamp + spec marker unchanged confirms no
        #      privileged switcher ran (catches the case where sudo
        #      *succeeded* via a stray policy).
        before = greetd_enter_ts()
        status, output = machine.execute(
            f"sudo -u {GAMING_USER} /run/current-system/sw/bin/switch-to-game-mode-user 2>&1"
        )
        assert status != 0, \
            f"steamosctl branch should fail (no DBus session in test VM); status=0 implies the arm exited without exec'ing steamosctl: {output!r}"
        assert "a password is required" not in output and "sudo:" not in output, \
            f"steamosctl branch must not fall through to sudo: {output!r}"
        after = greetd_enter_ts()
        assert after == before, \
            f"steamosctl branch must not restart greetd: {before} -> {after}"
        assert current_spec() == "gaming", \
            "steamosctl branch must not flip the spec"

    for cycle in range(1, 4):
        with subtest(f"round trip #{cycle}: gaming -> dev -> gaming"):
            run_switch("dev")
            assert_dev_active()
            # tmpfiles must refresh both symlinks each rebuild so the dev
            # toplevel doesn't keep pointing at the previous gaming
            # generation's store paths after a swap.
            for entry in (
                "switch-to-dev-mode.desktop",
                "switch-to-game-mode.desktop",
            ):
                target = machine.succeed(
                    f"readlink -f {GAMER_DESKTOP_DIR}/{entry}"
                ).strip()
                machine.succeed(f"test -e {target}")
            run_switch("game")
            assert_gaming_active()

    with subtest("idempotent: swapping to the current spec is safe"):
        # switch-to-configuration's activation scripts may still bounce
        # some units even when the toplevel matches (nixos-activation
        # always re-runs, restart triggers can fire on tmpfiles drift,
        # etc.), so don't assert on the greetd timestamp. We can't wait
        # on `is-active greetd.service` either — gaming greetd autologins
        # into gamescope which dies on the headless VM, taking greetd
        # with it. The weaker invariant we *can* assert is: the swap
        # exits cleanly and the spec marker remains gaming.
        run_switch("game")
        assert_gaming_active()

    with subtest("no service leaks after round trips"):
        final_units = running_services()
        leaked = final_units - baseline_units
        # Activation-side noise that isn't a real leak:
        #   nixos-activation re-runs on every switch.
        #   systemd-udevd bounces on hotplug events fired during the swap.
        #   rtkit-daemon is dbus-activated by gamescope-session asking for
        #     realtime priority and stays resident by design.
        # Each entry needs a justification; if this list grows, treat it
        # as a signal to investigate before silencing.
        ignored = {
            "nixos-activation.service",
            "systemd-udevd.service",
            "rtkit-daemon.service",
        }
        leaked -= ignored
        assert not leaked, f"new running services after round trips: {sorted(leaked)}"
  '';
}
