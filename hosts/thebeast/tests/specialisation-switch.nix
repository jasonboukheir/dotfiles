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
        # steamos-manager.service is jovian-only and must be torn down
        # by switch-to-configuration on the swap to dev. The baseline-
        # leak check at the bottom of this test can't see this miss
        # because steamos-manager is in `baseline_units` (we snapshot
        # while in gaming). Catching it here also detects the headline
        # bug from a different angle: if the privileged switcher
        # reaped itself before running switch-to-configuration, no
        # units were torn down — steamos-manager stays "active" even
        # though we believe we're in dev.
        assert unit_state("steamos-manager.service") != "active", \
            f"steamos-manager.service should be inactive in dev, got: {unit_state('steamos-manager.service')}"
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

    with subtest("gaming-spec shortcuts: dev swap + big picture, no in-spec game-mode"):
        # In gaming we want the swap-to-dev entry (so the user can leave
        # the gaming spec) and the in-place Big Picture entry. We must
        # NOT ship a game-mode entry here — we're already in gaming, and
        # the old steamosctl-based "Switch to Game Mode" desktop entry
        # tore down plasma to launch gamescope, which is the wrong
        # behavior when the user just wants Steam's gamepad UI.
        for entry in ("switch-to-dev-mode.desktop", "switch-to-big-picture.desktop"):
            machine.succeed(f"test -e {APPS_DIR}/{entry}")
        machine.fail(f"test -e {APPS_DIR}/switch-to-game-mode.desktop")
        machine.succeed("command -v switch-to-dev-mode-user")
        machine.succeed("command -v switch-to-big-picture")
        # No game-mode user wrapper in gaming spec.
        machine.fail("command -v switch-to-game-mode-user")
        # gamer's Desktop carries the two entries the plasma session
        # actually surfaces — and crucially not the legacy game-mode one.
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-dev-mode.desktop")
        machine.succeed(f"test -L {GAMER_DESKTOP_DIR}/switch-to-big-picture.desktop")
        machine.fail(f"test -e {GAMER_DESKTOP_DIR}/switch-to-game-mode.desktop")

        # The Big Picture wrapper must actually shut Steam down before
        # relaunching — otherwise the existing window keeps the
        # single-instance lock and `steam -gamepadui` no-ops back into
        # the same window. Inspect the rendered script (the
        # writeShellApplication output ends up as the executable on
        # PATH); both the shutdown call and the gamepadui exec must be
        # present.
        bp_script = machine.succeed("cat $(command -v switch-to-big-picture)")
        assert "steam -shutdown" in bp_script, \
            f"big-picture wrapper missing shutdown call:\n{bp_script}"
        assert "steam -gamepadui" in bp_script, \
            f"big-picture wrapper missing gamepadui launch:\n{bp_script}"

    with subtest("NOPASSWD sudo rule covers the outgoing direction only"):
        # `sudo -ll` enumerates every rule a user has. In gaming we only
        # need the switch-to-dev-mode rule (the only direction worth
        # escalating for); switch-to-game-mode would be a self-swap and
        # has no entry. A missing rule turns the desktop-shortcut click
        # into a silent password prompt the user can't satisfy.
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
            assert "switch-to-dev-mode" in rules, \
                f"{user} missing switch-to-dev-mode rule in gaming spec:\n{rules}"
            assert "switch-to-game-mode" not in rules, \
                f"{user} should not have a switch-to-game-mode rule in gaming spec:\n{rules}"
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
        # Session-bus activation file — jovian-setup-desktop-session
        # routes through steamosctl which hits the user instance via
        # this dbus service file. If services.dbus.packages stops
        # carrying steamos-manager, DefaultDesktopSession never gets
        # set and steamos-manager's Switch-to-Desktop dialog has no
        # entries.
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

        # The headline production bug: the desktop-entry click spawns
        # `switch-to-dev-mode-user` inside plasma's session-N.scope —
        # itself a child of user-{uid}.slice. The wrapper `exec sudo -n
        # switch-to-dev-mode`, but sudo does NOT migrate the process
        # out of the caller's cgroup, so the sudo'd root switcher is
        # still in user-{uid}.slice. The moment it calls
        # `systemctl stop user-{uid}.slice` systemd SIGTERMs every PID
        # in the slice (the switcher included) before
        # switch-to-configuration ever runs. plasma dies, the
        # framebuffer reverts to the kernel console ("just a tty"),
        # the spec marker stays gaming, steamos-manager never gets
        # stopped (visible as a shutdown-time log line at the next
        # reboot).
        #
        # `machine.execute("sudo -u {GAMING_USER} …")` would invoke
        # the wrapper from the test harness's own cgroup (outside the
        # slice) and silently bypass this — see the prior shape of
        # this subtest. Drive the wrapper through systemd-run so the
        # entire chain (wrapper → sudo → switcher → systemctl) is
        # parented to user-{uid}.slice exactly like production. `--wait
        # --collect --pipe` blocks for the result and surfaces stderr;
        # a self-reap exits 143 (128+SIGTERM) which is neither 0 nor
        # the tolerated 4.
        status, output = machine.execute(
            f"systemd-run --quiet --uid={GAMING_USER} "
            f"--slice=user-{uid}.slice --wait --collect --pipe -- "
            f"/run/current-system/sw/bin/switch-to-dev-mode-user"
        )
        assert status in SUCCESS_CODES, (
            f"switcher was reaped by its own `systemctl stop "
            f"user-{uid}.slice` before switch-to-configuration ran "
            f"(status={status}): {output!r}"
        )
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

    with subtest("dev-spec shortcuts: game-mode only, no dev-mode, no big-picture"):
        # In hyprland the only swap that makes sense is to gaming —
        # surfacing a dev-mode shortcut here would be a no-op the user
        # has to read past in their app launcher. Big Picture also
        # disappears: gamer isn't logged in, Steam isn't running, and
        # the launcher is a gaming-spec workflow.
        machine.succeed(f"test -e {APPS_DIR}/switch-to-game-mode.desktop")
        machine.fail(f"test -e {APPS_DIR}/switch-to-dev-mode.desktop")
        machine.fail(f"test -e {APPS_DIR}/switch-to-big-picture.desktop")
        machine.succeed("command -v switch-to-game-mode-user")
        machine.fail("command -v switch-to-dev-mode-user")
        machine.fail("command -v switch-to-big-picture")

    with subtest("dev-spec NOPASSWD rule covers swap-to-gaming only"):
        # Mirror of the gaming-spec rule audit. Defense-in-depth: even
        # if a stale switch-to-dev-mode binary lingered on PATH there's
        # no rule allowing an unprivileged escalation through it.
        for user in (DEV_USER, GAMING_USER):
            rules = machine.succeed(f"sudo -u {user} sudo -n -ll")
            assert "switch-to-game-mode" in rules, \
                f"{user} missing switch-to-game-mode rule in dev spec:\n{rules}"
            assert "switch-to-dev-mode" not in rules, \
                f"{user} should not have a switch-to-dev-mode rule in dev spec:\n{rules}"

    with subtest("unauthorized user cannot escalate via the user wrapper"):
        # The unauth user has no NOPASSWD rule, so sudo -n exits
        # non-zero and the wrapper propagates that. This is the negative
        # path the static permission check above can't prove on its own.
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

    with subtest("user wrapper as jasonbk in dev → escalates, swaps to gaming, and reaps the slice"):
        # Symmetric to the gamer→dev case above. Currently in dev with
        # tuigreet sitting on tty1 as `greeter`; jasonbk logs in and
        # hyprland takes over session-N.scope under user-{uid}.slice
        # (jasonbk), still bound to tty1. When jasonbk clicks
        # "Switch to Game Mode" from inside hyprland, the desktop
        # entry spawns switch-to-game-mode-user inside his session
        # scope — exactly the production cgroup parentage. If the
        # swapWrapper only retires the `greeter` slice (its compile-
        # time default) and leaves jasonbk's alive, the new gaming
        # greetd cannot reclaim tty1 to autologin gamer into
        # gamescope: hyprland keeps holding the framebuffer, the
        # gamescope launch dies, and the user sees a black, cursorless
        # screen on the kernel console (the headline bug).
        #
        # Drive the wrapper through `systemd-run --slice=user-{uid}.slice`
        # so the entire chain (wrapper → sudo → switcher → slice stop)
        # is parented to jasonbk's slice exactly like the click path.
        # `machine.execute("sudo -u jasonbk …")` would invoke from the
        # test harness's own cgroup and silently bypass the bug — the
        # prior shape of this subtest did that.
        uid = machine.succeed(f"id -u {DEV_USER}").strip()
        machine.succeed(f"loginctl enable-linger {DEV_USER}")
        machine.succeed(f"systemctl start user@{uid}.service")
        machine.wait_until_succeeds(f"systemctl is-active user@{uid}.service")
        machine.succeed(
            f"systemd-run --uid={DEV_USER} "
            f"--slice=user-{uid}.slice --unit=fake-hyprland "
            f"--no-block -- sleep 600"
        )
        machine.wait_until_succeeds("systemctl is-active fake-hyprland.service")

        before = greetd_enter_ts()

        status, output = machine.execute(
            f"systemd-run --quiet --uid={DEV_USER} "
            f"--slice=user-{uid}.slice --wait --collect --pipe -- "
            f"/run/current-system/sw/bin/switch-to-game-mode-user"
        )
        assert status in SUCCESS_CODES, (
            f"switcher was reaped or failed before switch-to-configuration "
            f"completed (status={status}): {output!r}"
        )
        assert_gaming_active()
        after = greetd_enter_ts()
        assert after > before, \
            f"jasonbk's NOPASSWD escalation should restart greetd: {before} -> {after}"

        # The swap must have torn down everything in jasonbk's slice —
        # both the transient (mimicking a session scope) and the user
        # manager. Without this teardown the new greetd can't claim
        # tty1, which is the visible-black-screen symptom on real
        # hardware. `is-active --quiet` exits 0 only when the unit is
        # active, so a non-zero exit covers every "reaped" state
        # (inactive, failed, gone) without parsing the printed line.
        fake_status, _ = machine.execute(
            "systemctl is-active --quiet fake-hyprland.service"
        )
        assert fake_status != 0, \
            "fake-hyprland should be reaped by the swap but is still active"
        slice_status, _ = machine.execute(
            f"systemctl is-active --quiet user-{uid}.slice"
        )
        assert slice_status != 0, \
            f"user-{uid}.slice should be inactive after swap but is still active"
        survivors = machine.succeed(
            f"ps -o pid,comm --no-headers -u {DEV_USER} 2>/dev/null || true"
        ).strip()
        assert not survivors, \
            f"jasonbk-owned processes survived the swap: {survivors!r}"

    with subtest("gamer in gaming → big-picture wrapper does not escalate or flip the spec"):
        # The plasma shortcut must launch Big Picture in-place; it must
        # NOT take the sudo path (no spec swap) and must NOT restart
        # greetd. Steam itself fails in the headless VM (no display, no
        # session bus), so the wrapper's `exec steam -gamepadui` exits
        # non-zero — that's the expected end state and is what
        # distinguishes "executed steam" from "fell through to a sudo
        # branch we shouldn't have". The sudo-denial sentinel rules out
        # the worst regression: silently routing through a privileged
        # switcher.
        before = greetd_enter_ts()
        status, output = machine.execute(
            f"sudo -u {GAMING_USER} /run/current-system/sw/bin/switch-to-big-picture 2>&1"
        )
        # status==0 would mean steam launched successfully in a headless
        # VM, which can't happen — treat as a regression signal.
        assert status != 0, \
            f"big-picture wrapper unexpectedly succeeded in headless VM: {output!r}"
        assert "a password is required" not in output and "sudo:" not in output, \
            f"big-picture wrapper must not call sudo: {output!r}"
        after = greetd_enter_ts()
        assert after == before, \
            f"big-picture wrapper must not restart greetd: {before} -> {after}"
        assert current_spec() == "gaming", \
            "big-picture wrapper must not flip the spec"

    for cycle in range(1, 4):
        with subtest(f"round trip #{cycle}: gaming -> dev -> gaming"):
            run_switch("dev")
            assert_dev_active()
            run_switch("game")
            assert_gaming_active()
            # gamer's Desktop is managed only by the gaming spec's
            # tmpfiles. On every return to gaming, the symlinks must
            # resolve to live store paths in the *current* gaming
            # closure — otherwise a fresh gaming rebuild leaves them
            # pointing at the previous generation's makeDesktopItem
            # outputs.
            for entry in (
                "switch-to-dev-mode.desktop",
                "switch-to-big-picture.desktop",
            ):
                target = machine.succeed(
                    f"readlink -f {GAMER_DESKTOP_DIR}/{entry}"
                ).strip()
                machine.succeed(f"test -e {target}")

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
