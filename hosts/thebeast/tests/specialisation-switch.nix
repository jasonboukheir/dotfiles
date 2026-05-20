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
    # Stubborn payload for the planted session scopes: the trap makes
    # it immune to SIGTERM so the test reaches the production code
    # path where wayland clients ignore SIGTERM and the slice/scope
    # stop blocks on its TimeoutStopSec. (`'''` is the Nix indented-
    # string escape for a literal `''`.)
    stubbornSleep = pkgs.writeShellScript "stubborn-sleep" ''
      trap ''' TERM
      exec ${pkgs.coreutils}/bin/sleep 600
    '';
  in ''
    import re
    import time
    import tomllib

    GAMING_USER = "${gamingUser}"
    DEV_USER = "${devUser}"
    UNAUTH_USER = "unauth"
    SESSIONS_ROOT = "${sessionsRoot}"
    SESSION_ENTRYPOINT_BIN = "${sessionEntrypointBin}"
    APPS_DIR = "${appsDir}"
    GAMER_DESKTOP_DIR = "${gamerDesktopDir}"
    DEFAULT_DESKTOP_SESSION = "${defaultDesktopSession}"
    STUBBORN_SLEEP = "${stubbornSleep}"

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

    def unit_enter_ts(unit):
        # Generalised version of greetd_enter_ts for any unit. 0 means the
        # unit has never been entered active (or was reset). Used to prove
        # critical units (logind, dbus) did NOT restart across a swap.
        out = machine.succeed(
            f"systemctl show -p ActiveEnterTimestampMonotonic --value {unit}"
        ).strip()
        return int(out) if out else 0

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
        #
        # Wait for the SIGTERM-driven stop to settle rather than
        # sampling once: with the session-scope-only swap the wrapper
        # returns as soon as switch-to-configuration completes, and
        # steamos-manager's TimeoutStopSec drain may still be in
        # flight (its drop-in caps the user-instance unit at 5s, but
        # the system-instance unit uses the default). A 30s ceiling
        # is well under that and still catches the "wrapper never ran
        # activation" regression — the unit would be permanently
        # active in that case.
        machine.wait_until_fails(
            "systemctl is-active --quiet steamos-manager.service",
            timeout=30,
        )
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

    def spec_switch_holdouts(scope):
        # Pull the wrapper's SIGTERM-holdout log lines from journald.
        # The wrapper emits them via `systemd-cat -t spec-switch` between
        # SIGTERM and SIGKILL, so any planted stubborn-sleep scope must
        # show up here. If this returns empty after a real swap, either
        # the logging code regressed or the test fake started honouring
        # SIGTERM (in which case the test isn't reaching the production
        # code path any more).
        return machine.succeed(
            f"journalctl -t spec-switch --no-pager --output=cat | "
            f"grep -F {scope!r} || true"
        ).strip()

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
        # Plant a SIGTERM-resistant session scope under gamer's slice,
        # mirroring how logind sets up real plasma sessions (under
        # session-<N>.scope, with wayland clients inside). The payload
        # ignores SIGTERM so the test reaches the production code path
        # — without this, a plain `sleep 600` exits instantly on
        # SIGTERM and the slow-scope-stop bug stays hidden.
        # `systemd-run --scope` blocks for the lifetime of the
        # supervised command, so wrap it in `( ... & )` to fully
        # detach: the subshell forks the systemd-run into a new
        # process group, redirects its stdio away, then exits — the
        # outer machine.succeed returns instantly while the scope
        # keeps running in the background. The scope name follows
        # logind's session-<N>.scope pattern so the wrapper's session-
        # scope filter picks it up exactly like a real session.
        machine.succeed(
            f"( systemd-run --scope --uid={GAMING_USER} "
            f"--slice=user-{uid}.slice --unit=session-901.scope "
            f"--collect --quiet -- {STUBBORN_SLEEP} "
            f"</dev/null >/dev/null 2>&1 & )"
        )
        machine.wait_until_succeeds("systemctl is-active session-901.scope")

        before = greetd_enter_ts()
        # Same wallclock bound as the dev → gaming direction. The
        # swapWrapper is shared, so a regression in either direction
        # shows up here too.
        SWAP_BUDGET_S = 45.0
        swap_started = time.monotonic()

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
        swap_elapsed = time.monotonic() - swap_started
        assert status in SUCCESS_CODES, (
            f"switcher was reaped by its own `systemctl stop "
            f"user-{uid}.slice` before switch-to-configuration ran "
            f"(status={status}, elapsed={swap_elapsed:.1f}s): {output!r}"
        )
        assert swap_elapsed < SWAP_BUDGET_S, (
            f"gaming → dev swap took {swap_elapsed:.1f}s (budget {SWAP_BUDGET_S}s); "
            "a SIGTERM-resistant process in the user slice should be force-killed, "
            "not waited out for TimeoutStopSec"
        )
        # Regression guard for the EACCES failure mode we hit during
        # bringup: status=4 alone is tolerated by the wrapper (legit
        # cases include "user not logged in to reload"), but if a
        # future refactor reintroduces the slice-stop pattern it will
        # tear down /run/user/<uid> mid-activation and switch-to-
        # configuration's user-unit reload will EACCES on
        # /run/user/<uid>/nixos. Catch that string directly so the
        # regression doesn't ride in under a tolerated exit code.
        assert "/run/user/" not in output and "Permission denied" not in output, (
            "switch-to-configuration touched a torn-down /run/user/<uid>; "
            f"the session-scope-only wrapper must keep user-runtime-dir alive:\n{output}"
        )
        assert_dev_active()
        after = greetd_enter_ts()
        assert after > before, \
            f"gamer's NOPASSWD escalation should restart greetd: {before} -> {after}"

        # The wrapper must have torn down the planted session scope
        # (this is what holds tty1/DRM in production). `is-active
        # --quiet` exits 0 only when the unit is active, so a non-zero
        # exit covers every "reaped" state (inactive, failed, gone)
        # without parsing the printed line.
        scope_status, _ = machine.execute(
            "systemctl is-active --quiet session-901.scope"
        )
        assert scope_status != 0, \
            "session-901.scope should be reaped by the swap but is still active"
        # No leftover wayland-client processes owned by gamer. The
        # user manager (user@<uid>.service) is allowed to stay alive
        # — switch-to-configuration needs it to reload user units —
        # so we filter the stubborn-sleep PIDs specifically rather
        # than asserting an empty `ps -u`. `pgrep` exits 1 with no
        # matches, which would trip the harness's `set -e`; the `||
        # true` collapses that to a clean empty stdout.
        survivors = machine.succeed(
            f"pgrep -u {GAMING_USER} -f stubborn-sleep || true"
        ).strip()
        assert not survivors, \
            f"stubborn-sleep survivors after swap: {survivors!r}"
        # The planted SIGTERM-resistant payload must have been logged as a
        # holdout. This is the diagnostic trail future debugging will pull
        # via `journalctl -t spec-switch -b` to find which real-world
        # clients (electron, browsers) routinely need SIGKILL.
        holdouts = spec_switch_holdouts("session-901.scope")
        assert holdouts, (
            "wrapper should have logged the stubborn-sleep as a SIGTERM "
            "holdout under tag spec-switch; nothing found for session-901.scope"
        )

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

        # Plant a SIGTERM-resistant session scope under jasonbk's slice.
        # Production Hyprland sessions live in session-<N>.scope under
        # user-<uid>.slice (logind-created) and carry wayland clients
        # (electron apps, xwayland, pipewire helpers, web browsers)
        # that don't always exit on SIGTERM. `systemctl stop` honours
        # the scope's TimeoutStopSec — systemd default is 90s — before
        # escalating to SIGKILL, so the slowest holdout sets the floor
        # on swap latency. That is the "blinking caret then minutes of
        # black screen" symptom on dev → gaming: tty1 reverts to the
        # kernel console (caret) the moment Hyprland's compositor
        # dies, then everything sits there until the scope finally
        # drains and switch-to-configuration can restart greetd into
        # gaming.
        #
        # The prior `sleep 600` fake exited instantly on SIGTERM,
        # hiding this. The stubborn-sleep helper traps SIGTERM so the
        # holdout is immune. Wrap systemd-run --scope in `( ... & )`
        # to fully detach (the systemd-run blocks for the lifetime of
        # the supervised command otherwise). The scope name matches
        # logind's `session-<N>.scope` so the wrapper's session-scope
        # filter picks it up exactly like a real session.
        machine.succeed(
            f"( systemd-run --scope --uid={DEV_USER} "
            f"--slice=user-{uid}.slice --unit=session-902.scope "
            f"--collect --quiet -- {STUBBORN_SLEEP} "
            f"</dev/null >/dev/null 2>&1 & )"
        )
        machine.wait_until_succeeds("systemctl is-active session-902.scope")

        before = greetd_enter_ts()
        # Snapshot logind/dbus enter timestamps. The activation script of
        # the gaming toplevel must not restart these — if it does, every
        # existing logind session enters `closing` and the new gaming
        # autologin queues behind PAM cleanup. The user perceives this as
        # a black screen of indeterminate duration.
        logind_before = unit_enter_ts("systemd-logind.service")
        dbus_before = unit_enter_ts("dbus.service")
        # The headline production bound: real users report "3s caret then
        # ~2 minutes of black". The dominant component is the user slice's
        # default 90s TimeoutStopSec. With the SIGKILL fast-path that this
        # test will drive, the entire swap should complete well under 30s.
        # Pick 45s as a generous-but-still-failing-the-bug budget — the
        # production symptom would blow well past this.
        SWAP_BUDGET_S = 45.0
        swap_started = time.monotonic()

        status, output = machine.execute(
            f"systemd-run --quiet --uid={DEV_USER} "
            f"--slice=user-{uid}.slice --wait --collect --pipe -- "
            f"/run/current-system/sw/bin/switch-to-game-mode-user"
        )
        swap_elapsed = time.monotonic() - swap_started
        assert status in SUCCESS_CODES, (
            f"switcher was reaped or failed before switch-to-configuration "
            f"completed (status={status}, elapsed={swap_elapsed:.1f}s): {output!r}"
        )
        # Wallclock budget reproduces the production "2 minutes of black"
        # symptom directly: a slice with a SIGTERM-resistant holdout takes
        # ~90s to stop via plain `systemctl stop`. If this assertion fires
        # at ~90s it points squarely at the slice-stop TimeoutStopSec.
        assert swap_elapsed < SWAP_BUDGET_S, (
            f"dev → gaming swap took {swap_elapsed:.1f}s (budget {SWAP_BUDGET_S}s); "
            "a SIGTERM-resistant process in the user slice should be force-killed, "
            "not waited out for TimeoutStopSec"
        )
        # Regression guard against the EACCES on /run/user/<uid> failure
        # we hit during bringup — see the symmetric assertion in the
        # gaming → dev subtest above for the rationale.
        assert "/run/user/" not in output and "Permission denied" not in output, (
            "switch-to-configuration touched a torn-down /run/user/<uid>; "
            f"the session-scope-only wrapper must keep user-runtime-dir alive:\n{output}"
        )

        assert_gaming_active()
        after = greetd_enter_ts()
        assert after > before, \
            f"jasonbk's NOPASSWD escalation should restart greetd: {before} -> {after}"

        # Regression guard for the "switch-to-desktop hangs on the second
        # round-trip" bug. jovian's 60-steam-input.rules tags /dev/uinput
        # and /dev/hidraw* with TAG+="uaccess" so logind ACLs them to the
        # current session user. switch-to-configuration's `udevadm control
        # --reload-rules` only changes how *future* uevents are processed;
        # /dev/uinput exists from the boot-time module load and never
        # re-fires "add", so the new spec's rules don't reach the existing
        # node. Without the wrapper's `udevadm trigger`, gamer's next
        # gamescope-session brings up the user-instance steamos-manager,
        # which fails "Starting udev-monitor → Permission denied" opening
        # /dev/uinput, crash-loops under TimeoutStartSec for ~3 minutes,
        # and the subsequent Steam "Switch to Desktop" hangs because
        # steamosctl can't reach the daemon. Assert the tag is present in
        # /run/udev/data after the swap. `/dev/uinput` may not exist in
        # the test VM if the kernel module isn't loadable; gate the check
        # on its presence rather than failing on infrastructure gaps.
        if machine.execute("test -e /dev/uinput")[0] == 0:
            tags = machine.succeed(
                "udevadm info --query=property /dev/uinput | "
                "awk -F= '/^(CURRENT_)?TAGS=/ { print $2 }' || true"
            )
            assert "uaccess" in tags, (
                "after dev → gaming the wrapper must `udevadm trigger` "
                "existing nodes so jovian's 60-steam-input.rules re-tags "
                f"/dev/uinput with uaccess; got tags={tags!r}"
            )

        # logind/dbus must survive the swap untouched. A restart here
        # forces every active session into `closing`, and the new gaming
        # autologin can't open a PAM session until cleanup completes —
        # which is itself bounded by user-runtime-dir@.service's stop
        # timeout. Either restart explains "minutes of black".
        logind_after = unit_enter_ts("systemd-logind.service")
        dbus_after = unit_enter_ts("dbus.service")
        assert logind_after == logind_before, (
            f"systemd-logind restarted across dev → gaming "
            f"({logind_before} -> {logind_after}); active sessions would "
            "enter `closing` and block the gaming autologin"
        )
        assert dbus_after == dbus_before, (
            f"dbus.service restarted across dev → gaming "
            f"({dbus_before} -> {dbus_after}); session-bus clients lose "
            "connections and reconnects stall the new session"
        )

        # The wrapper must have torn down the planted session scope
        # (this is what holds tty1/DRM in production). The user manager
        # (user@<uid>.service) and runtime dir intentionally survive —
        # switch-to-configuration needs them to reload user units, and
        # killing them abruptly produced the EACCES on /run/user/<uid>
        # that motivated the session-scope-only design.
        scope_status, _ = machine.execute(
            "systemctl is-active --quiet session-902.scope"
        )
        assert scope_status != 0, \
            "session-902.scope should be reaped by the swap but is still active"
        # No leftover wayland-client processes: assert the stubborn-
        # sleep helper PIDs are gone. user@<uid>.service workers
        # (systemd, dbus, etc.) are allowed to remain. `pgrep` exits 1
        # with no matches; `|| true` collapses that into clean empty
        # stdout so the harness `set -e` doesn't trip.
        survivors = machine.succeed(
            f"pgrep -u {DEV_USER} -f stubborn-sleep || true"
        ).strip()
        assert not survivors, \
            f"stubborn-sleep survivors after swap: {survivors!r}"
        # Same diagnostic-trail guarantee as the gaming → dev direction:
        # the planted holdout must show up under tag spec-switch so future
        # debugging on real hardware (where the real offenders are
        # electron/chromium/steamwebhelper) has a journal to grep.
        holdouts = spec_switch_holdouts("session-902.scope")
        assert holdouts, (
            "wrapper should have logged the stubborn-sleep as a SIGTERM "
            "holdout under tag spec-switch; nothing found for session-902.scope"
        )

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
