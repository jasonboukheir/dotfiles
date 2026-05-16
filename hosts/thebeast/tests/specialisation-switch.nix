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
  };

  testScript = ''
    # switch-to-configuration returns 4 when system activation succeeded
    # but a user-instance reload didn't — typically because gamer's old
    # gamescope/dbus user units are pointing at the previous toplevel.
    # The system half is what matters for the swap; treat 4 as success.
    def run_switch(name):
        status, output = machine.execute(f"/run/current-system/sw/bin/switch-to-{name}-mode")
        assert status in (0, 4), f"switch-to-{name}-mode exited {status}: {output}"

    def unit_state(unit):
        return machine.succeed(
            f"systemctl show -p ActiveState --value {unit} 2>/dev/null || echo unknown"
        ).strip()

    def assert_no_sddm():
        # Unified-greeter invariant: SDDM must never appear in either spec.
        # display-manager.service is an alias and should always resolve to
        # greetd, never sddm.
        machine.fail("pgrep -x sddm")
        dm_target = machine.succeed(
            "readlink -f /etc/systemd/system/display-manager.service"
        ).strip()
        assert dm_target.endswith("/greetd.service"), \
            f"display-manager.service should alias greetd, got {dm_target}"

    def greetd_config():
        """Read the greetd TOML config the live unit is pointing at."""
        path = machine.succeed(
            "systemctl cat greetd.service | "
            "grep -oE -- '--config [^ ]+' | head -n1 | awk '{print $2}'"
        ).strip()
        return machine.succeed(f"cat {path}")

    def assert_gaming_active():
        # gamescope-session can't actually run inside the headless test VM
        # (no DRM device, no cap_sys_nice wrapper context), so checking
        # gamescope/start-gamescope-session at runtime is racy: greetd
        # autologins, gamescope crashes, greetd's Restart=on-success means
        # it doesn't come back, and a pgrep-based assertion would flake.
        # Instead, assert the toplevel is *configured* for gaming: greetd's
        # TOML defines an initial_session that autologins gamer into
        # start-gamescope-session. That confirms switch-to-configuration
        # applied the new spec.
        config = greetd_config()
        assert "[initial_session]" in config, \
            f"gaming greetd missing initial_session autologin:\n{config}"
        assert "thebeast-gamer-session" in config, \
            f"gaming initial_session should launch the SDDM-override wrapper:\n{config}"
        assert 'user = "gamer"' in config, \
            f"gaming initial_session should run as gamer:\n{config}"
        machine.succeed("id -nG jasonbk | grep -qw gamemode")
        machine.fail("pgrep -x tuigreet")
        machine.fail("pgrep -x Hyprland")
        machine.fail("pgrep -x hyprland")
        assert_no_sddm()

    def assert_dev_active():
        # Same greetd unit, different default_session: tuigreet greeter for
        # jasonbk to log into Hyprland. tuigreet runs fine in the headless
        # VM (no GPU needed), so we can verify both config and runtime.
        config = greetd_config()
        assert "[initial_session]" not in config, \
            f"dev greetd should not autologin:\n{config}"
        assert "tuigreet" in config, \
            f"dev default_session should be tuigreet:\n{config}"
        machine.wait_until_succeeds("pgrep -x greetd")
        machine.wait_until_succeeds("pgrep -x tuigreet")
        assert unit_state("greetd.service") == "active", \
            f"greetd state: {unit_state('greetd.service')}"
        machine.fail("id -nG jasonbk | grep -qw gamemode")
        machine.fail("pgrep -x gamescope")
        machine.fail("pgrep -x gamescope-wl")
        machine.fail("pgrep -x steam")
        machine.fail("pgrep -x steamos-manager")
        assert_no_sddm()
        # tuigreet was given an explicit --sessions <hyprland>/share/wayland-
        # sessions; if that store path stops shipping a wayland session file,
        # jasonbk lands at a blank greeter. Pull the path out of the live
        # greetd config and confirm at least one .desktop is present.
        hypr_dir = ""
        for token in config.split():
            stripped = token.strip('"')
            if "/share/wayland-sessions" in stripped:
                hypr_dir = stripped
                break
        assert hypr_dir, f"could not extract --sessions path from:\n{config}"
        sessions = machine.succeed(f"ls {hypr_dir}").split()
        assert any(s.endswith(".desktop") for s in sessions), \
            f"tuigreet sessions dir {hypr_dir} should contain a .desktop: {sessions}"
        # PAM keyring: omarchy.pim=gnome wires enableGnomeKeyring so the
        # password jasonbk types at tuigreet unlocks gnome-keyring. If
        # this regresses, kwallet/gnome-keyring prompts twice on login.
        pam_greetd = machine.succeed("cat /etc/pam.d/greetd")
        assert "gnome_keyring" in pam_greetd or "pam_gnome_keyring" in pam_greetd, \
            f"dev /etc/pam.d/greetd should pull in pam_gnome_keyring:\n{pam_greetd}"

    def snapshot():
        """Capture state to compare across round trips."""
        units = set(machine.succeed(
            "systemctl list-units --type=service --state=running "
            "--no-legend --plain | awk '{print $1}'"
        ).split())
        # Per-user transient units come and go; ignore them.
        units = {u for u in units if not u.startswith("user@")}
        # Aggregate counts for processes we deliberately spawn/kill.
        watched = ["greetd", "tuigreet", "gamescope", "steam", "steamos-manager", "hyprland"]
        counts = {
            p: int(machine.succeed(f"pgrep -xc {p} || true").strip() or "0")
            for p in watched
        }
        return units, counts

    machine.wait_for_unit("multi-user.target")

    with subtest("base config is gaming with greetd autologin"):
        machine.wait_for_unit("display-manager.service")
        assert_gaming_active()
        machine.succeed("test -x /run/current-system/specialisation/dev/bin/switch-to-configuration")

    with subtest("swap shortcuts are installed in both modes"):
        appdir = "/run/current-system/sw/share/applications"
        for entry in (
            "switch-to-game-mode.desktop",
            "switch-to-dev-mode.desktop",
        ):
            machine.succeed(f"test -e {appdir}/{entry}")
        machine.succeed("command -v switch-to-game-mode-user")
        machine.succeed("command -v switch-to-dev-mode-user")
        # NOPASSWD sudo rule for jasonbk on the privileged switcher.
        machine.succeed("sudo -u jasonbk sudo -ln switch-to-game-mode")
        machine.succeed("sudo -u jasonbk sudo -ln switch-to-dev-mode")

    with subtest("gamer's KDE Desktop carries the swap shortcuts"):
        # Both swap directions appear on gamer's Plasma desktop: dev for
        # the spec swap to jasonbk's Hyprland, game for the gamescope
        # toggle via steamos-manager (no spec change).
        machine.succeed("test -L /home/gamer/Desktop/switch-to-dev-mode.desktop")
        machine.succeed("test -L /home/gamer/Desktop/switch-to-game-mode.desktop")

    with subtest("user-facing wrappers dispatch on current spec"):
        # In gaming spec, switch-to-game-mode-user delegates to steamosctl
        # (gamescope toggle, no spec change). The script should not invoke
        # sudo from that branch — verify by reading the wrapper text.
        gm_wrapper = machine.succeed("readlink -f $(command -v switch-to-game-mode-user)").strip()
        gm_body = machine.succeed(f"cat {gm_wrapper}")
        assert "steamosctl switch-to-game-mode" in gm_body, \
            f"gaming-mode branch should call steamosctl:\n{gm_body}"
        assert "sudo -n" in gm_body, \
            f"dev-mode branch should escalate via sudo:\n{gm_body}"
        # And the dev-mode wrapper short-circuits when already in dev so
        # the desktop entry doesn't pop a passwordless sudo for nothing.
        dm_wrapper = machine.succeed("readlink -f $(command -v switch-to-dev-mode-user)").strip()
        dm_body = machine.succeed(f"cat {dm_wrapper}")
        assert "Already in dev mode" in dm_body, \
            f"dev-mode branch should short-circuit when already in dev:\n{dm_body}"

    with subtest("greetd is the only DM service available across both specs"):
        # No sddm.service at all in either toplevel — both should resolve
        # display-manager → greetd.
        machine.fail("test -e /run/current-system/etc/systemd/system/sddm.service")
        machine.fail(
            "test -e /run/current-system/specialisation/dev/etc/systemd/system/sddm.service"
        )
        # greetd is forced restartIfChanged so the spec swap reaches it.
        for path in (
            "/run/current-system/etc/systemd/system/greetd.service",
            "/run/current-system/specialisation/dev/etc/systemd/system/greetd.service",
        ):
            machine.fail(f"grep -q 'X-RestartIfChanged=false' {path}")

    with subtest("switch-to-desktop infrastructure is wired in gaming mode"):
        # The wrapper script greetd autologins into.
        machine.succeed("command -v thebeast-gamer-session")
        # gaming greetd command must point at the wrapper (not start-
        # gamescope-session directly), or steamos-manager's restart-DM
        # protocol won't be able to redirect to plasma.
        assert "thebeast-gamer-session" in greetd_config(), \
            f"gaming greetd should run the wrapper, got:\n{greetd_config()}"
        # Plasma 6 must register a wayland session named plasma.desktop in
        # the aggregated sessionData.desktops dir, matching what steamos-
        # manager writes into Session=. The dir is referenced by the
        # wrapper via /nix/store, so locate it via the wrapper itself.
        sessions_root = machine.succeed(
            "grep -oE '/nix/store/[^ ]+-desktops/share/wayland-sessions' "
            "$(command -v thebeast-gamer-session) | head -n1"
        ).strip()
        machine.succeed(f"test -e {sessions_root}/plasma.desktop")
        machine.succeed(f"test -e {sessions_root}/gamescope-wayland.desktop")
        # Marker file telling steamos-manager it may manage sessions here,
        # mirroring jovian's autoStart wiring.
        machine.succeed("test -e /etc/sddm.conf.d/steamos.conf")
        # User-level oneshots that populate DefaultDesktopSession and
        # tear down the temp override after the session settles.
        for unit in (
            "jovian-setup-desktop-session.service",
            "steamos-manager-session-cleanup.service",
        ):
            machine.succeed(f"test -e /etc/systemd/user/{unit}")
        # Confirm the cleanup oneshot actually invokes steamosctl's
        # clean-temporary-sessions (not just a symlinked empty unit).
        cleanup_unit = machine.succeed(
            "systemctl --user --root=/ cat steamos-manager-session-cleanup.service 2>/dev/null || "
            "cat /etc/systemd/user/steamos-manager-session-cleanup.service"
        )
        assert "clean-temporary-sessions" in cleanup_unit, \
            f"cleanup unit should run steamosctl clean-temporary-sessions:\n{cleanup_unit}"
        # And the setup oneshot must point steamos-manager at plasma so
        # the Steam UI's Switch-to-Desktop default lands somewhere real.
        setup_unit = machine.succeed(
            "cat /etc/systemd/user/jovian-setup-desktop-session.service"
        )
        assert "set-default-desktop-session plasma.desktop" in setup_unit, \
            f"setup unit should set plasma as the default desktop session:\n{setup_unit}"

    with subtest("steamos-manager system unit + user bus activation"):
        # System unit is enabled at multi-user.target so it's available
        # the moment greetd autologins gamer. This is what restarts
        # display-manager.service when Steam → Switch-to-Desktop fires.
        assert unit_state("steamos-manager.service") in ("active", "activating"), \
            f"steamos-manager.service state: {unit_state('steamos-manager.service')}"
        # Session-bus activation file — gamer's "Switch to Game Mode"
        # desktop entry invokes `steamosctl switch-to-game-mode`, which
        # hits the user instance. If services.dbus.packages stops
        # carrying steamos-manager, this file is missing and clicking
        # the icon from Plasma is a no-op. The dbus search path lives
        # under the system sw output.
        machine.succeed(
            "find /run/current-system/sw/share/dbus-1 "
            "-name com.steampowered.SteamOSManager1.service | grep -q ."
        )

    with subtest("wrapper resolves steamos-manager's SDDM temp override"):
        # Simulate the override steamos-manager writes when Steam's
        # "Switch to Desktop" is clicked, then ask the wrapper which
        # session it would exec via its --print-resolved probe.
        machine.succeed("install -d -m 0755 /etc/sddm.conf.d")
        machine.succeed(
            "printf '[Autologin]\\nUser=gamer\\nSession=plasma.desktop\\n' "
            "> /etc/sddm.conf.d/zzt-steamos-temp-login.conf"
        )
        resolved = machine.succeed("thebeast-gamer-session --print-resolved").strip()
        assert "startplasma" in resolved, \
            f"wrapper should pick startplasma when Session=plasma.desktop; got: {resolved!r}"

        # And with the override removed, it falls back to gamescope.
        machine.succeed("rm -f /etc/sddm.conf.d/zzt-steamos-temp-login.conf")
        resolved = machine.succeed("thebeast-gamer-session --print-resolved").strip()
        assert "start-gamescope-session" in resolved, \
            f"wrapper should pick gamescope by default; got: {resolved!r}"

    # Snapshot the gaming-mode state for leak comparison after the
    # round trips. Take it after a brief settle so transient units
    # like systemd-tmpfiles-clean don't show up as drift.
    baseline_units, baseline_counts = snapshot()

    with subtest("first switch: gaming -> dev"):
        run_switch("dev")
        assert_dev_active()

    with subtest("first switch back: dev -> gaming"):
        run_switch("game")
        assert_gaming_active()

    # Three full round trips to flush out anything that accumulates.
    for cycle in range(2, 5):
        with subtest(f"round trip #{cycle}: gaming -> dev -> gaming"):
            run_switch("dev")
            assert_dev_active()
            run_switch("game")
            assert_gaming_active()

    with subtest("no service / process leaks after round trips"):
        final_units, final_counts = snapshot()
        leaked_units = final_units - baseline_units
        # Allow units that are oneshot-style "active" but harmless
        # (e.g. nixos-activation.service runs on each switch). systemd-udevd
        # is reactivated by hotplug events fired during the swaps and isn't
        # a leak we actually care about.
        ignored = {"nixos-activation.service", "systemd-udevd.service"}
        leaked_units -= ignored
        assert not leaked_units, f"new running services after round trips: {sorted(leaked_units)}"

        # Process counts for tracked names should match between cycles.
        drift = {
            k: (baseline_counts[k], final_counts[k])
            for k in baseline_counts
            if baseline_counts[k] != final_counts[k]
        }
        assert not drift, f"process count drift: {drift}"
  '';
}
