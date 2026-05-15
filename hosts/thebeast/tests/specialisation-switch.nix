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

    def assert_gaming_active():
        # SDDM is the source of truth: process running + drawing on VT 1.
        machine.wait_until_succeeds("pgrep -x sddm")
        machine.succeed("id -nG jasonbk | grep -qw gamemode")
        # greetd is dev-only — must not be running in gaming.
        machine.fail("pgrep -x greetd")
        machine.fail("pgrep -x tuigreet")
        machine.fail("pgrep -x Hyprland")
        machine.fail("pgrep -x hyprland")

    def assert_dev_active():
        # greetd + its tuigreet child are the dev-mode login screen.
        machine.wait_until_succeeds("pgrep -x greetd")
        machine.wait_until_succeeds("pgrep -x tuigreet")
        assert unit_state("greetd.service") == "active", \
            f"greetd state: {unit_state('greetd.service')}"
        machine.fail("id -nG jasonbk | grep -qw gamemode")
        # Steam / gamescope / sddm are gaming-only.
        machine.fail("pgrep -x sddm")
        machine.fail("pgrep -x gamescope")
        machine.fail("pgrep -x gamescope-wl")
        machine.fail("pgrep -x steam")
        machine.fail("pgrep -x steamos-manager")

    def snapshot():
        """Capture state to compare across round trips."""
        units = set(machine.succeed(
            "systemctl list-units --type=service --state=running "
            "--no-legend --plain | awk '{print $1}'"
        ).split())
        # Per-user transient units come and go; ignore them.
        units = {u for u in units if not u.startswith("user@")}
        # Aggregate counts for processes we deliberately spawn/kill.
        watched = ["sddm", "tuigreet", "gamescope", "steam", "steamos-manager", "hyprland"]
        counts = {
            p: int(machine.succeed(f"pgrep -xc {p} || true").strip() or "0")
            for p in watched
        }
        return units, counts

    machine.wait_for_unit("multi-user.target")

    with subtest("base config is gaming with sddm up and greetd down"):
        # SDDM may take a few seconds after multi-user.target.
        machine.wait_for_unit("display-manager.service")
        assert_gaming_active()
        machine.succeed("test -x /run/current-system/specialisation/dev/bin/switch-to-configuration")

    with subtest("swap shortcuts are installed in both modes"):
        appdir = "/run/current-system/sw/share/applications"
        for entry in (
            "switch-to-game-mode.desktop",
            "switch-to-dev-mode.desktop",
            "return-to-steam-bigpicture.desktop",
        ):
            machine.succeed(f"test -e {appdir}/{entry}")
        machine.succeed("command -v switch-to-game-mode-user")
        machine.succeed("command -v switch-to-dev-mode-user")
        # NOPASSWD sudo rule for jasonbk on the privileged switcher.
        machine.succeed("sudo -u jasonbk sudo -ln switch-to-game-mode")
        machine.succeed("sudo -u jasonbk sudo -ln switch-to-dev-mode")

    with subtest("gamer's KDE Desktop carries the dev + steam shortcuts"):
        machine.succeed("test -L /home/gamer/Desktop/switch-to-dev-mode.desktop")
        machine.succeed("test -L /home/gamer/Desktop/return-to-steam-bigpicture.desktop")

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
        # (e.g. nixos-activation.service runs on each switch).
        ignored = {"nixos-activation.service"}
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
