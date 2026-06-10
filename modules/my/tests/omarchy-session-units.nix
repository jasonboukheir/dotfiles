# Native (NixOS-layer) omarchy session units: prove they are wired to
# omarchy.sessionTarget and actually runnable inside a real wayland user
# session (headless weston standing in for Hyprland, issue #48).
{
  pkgs,
  inputs ? null,
}:
pkgs.testers.nixosTest {
  name = "omarchy-session-units";

  nodes.machine = {lib, ...}: {
    nixpkgs.pkgs = pkgs.extend (import ../../nixpkgs/overlays/mkWrapped.nix);
    imports = [
      inputs.home-manager-nixos-unstable.nixosModules.home-manager
      ../../omarchy
      ../nixos.nix
      # omarchy/packages.nix writes allowUnfreePackageNames, whose real home
      # (modules/nixpkgs/unfreepackages.nix) also sets nixpkgs.config — which
      # nixosTest refuses once nixpkgs.pkgs is injected. Stub the option
      # surface only; the test pkgs is already built with allowUnfree = true.
      {
        options.allowUnfreePackageNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
        };
      }
    ];

    omarchy.enable = true;
    programs._1password-gui.enable = true;

    users.users.tester = {
      isNormalUser = true;
      password = "tester";
    };

    environment.systemPackages = [pkgs.weston];
  };

  testScript = {nodes, ...}: let
    sessionTarget = nodes.machine.omarchy.sessionTarget;
  in ''
    SESSION_TARGET = "${sessionTarget}"
    SERVICES = [
        "hyprsunset",
        "wl-clip-persist",
        "clipse",
        "hyprpolkitagent",
        "_1password",
    ]

    machine.wait_for_unit("multi-user.target")

    uid = machine.succeed("id -u tester").strip()
    run_dir = f"/run/user/{uid}"

    def user(cmd):
        return machine.succeed(
            f"su - tester -c 'export XDG_RUNTIME_DIR={run_dir}; {cmd}'"
        )

    with subtest("all units are installed and wanted by the session target"):
        for svc in SERVICES:
            machine.succeed(f"test -e /etc/systemd/user/{svc}.service")
            machine.succeed(
                f"test -L /etc/systemd/user/{SESSION_TARGET}.wants/{svc}.service"
            )

    with subtest("units order against and die with the session target"):
        for svc in SERVICES:
            unit = machine.succeed(f"cat /etc/systemd/user/{svc}.service")
            assert f"After={SESSION_TARGET}" in unit, f"{svc} misses After:\n{unit}"
            assert f"PartOf={SESSION_TARGET}" in unit, f"{svc} misses PartOf:\n{unit}"
            assert "ConditionEnvironment" not in unit, (
                f"{svc} must rely on the sessionTarget gate, not "
                f"ConditionEnvironment (issue #32):\n{unit}"
            )

    with subtest("user manager comes up for the test user"):
        machine.succeed("loginctl enable-linger tester")
        machine.wait_until_succeeds(f"test -S {run_dir}/bus")

    with subtest("headless weston provides a wayland session"):
        user(
            "systemd-run --user --unit=weston-headless -- "
            "weston --backend=headless --socket=wayland-1"
        )
        machine.wait_until_succeeds(f"test -S {run_dir}/wayland-1")
        user("systemctl --user set-environment WAYLAND_DISPLAY=wayland-1")

    with subtest("clipse and wl-clip-persist start and stay active"):
        user("systemctl --user start clipse wl-clip-persist")
        for svc in ("clipse", "wl-clip-persist"):
            machine.wait_until_succeeds(
                f"su - tester -c 'export XDG_RUNTIME_DIR={run_dir}; "
                f"systemctl --user is-active {svc}'"
            )

    with subtest("hyprsunset is attempted with the right binary"):
        # hyprsunset speaks Hyprland-specific protocols, so under weston it
        # may exit immediately; the wiring (right ExecStart, an actual exec
        # attempt) is what this asserts. If it stays up, even better.
        exec_start = user("systemctl --user show -p ExecStart hyprsunset")
        assert "/bin/hyprsunset" in exec_start, f"bad ExecStart: {exec_start}"
        machine.execute(
            f"su - tester -c 'export XDG_RUNTIME_DIR={run_dir}; "
            "systemctl --user start hyprsunset'"
        )
        machine.wait_until_succeeds(
            f"journalctl --user-unit=hyprsunset _UID={uid} | grep -q ."
        )
        state = user(
            "systemctl --user show -p ActiveState,SubState hyprsunset"
        ).strip()
        print(f"hyprsunset under headless weston: {state}")
        # Restart=always would otherwise retry forever in the background.
        user("systemctl --user stop hyprsunset || true")

    with subtest("clipse client binary is on PATH for the Hyprland binding"):
        machine.succeed("test -x /run/current-system/sw/bin/clipse")
  '';
}
