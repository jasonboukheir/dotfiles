# Native (NixOS-layer) omarchy session units: prove they are wired to
# omarchy.sessionTarget, actually runnable inside a real wayland user
# session (headless weston standing in for Hyprland, issue #48), and —
# under uwsm — pulled up by the real wayland-session@hyprland.desktop
# unit graph with WAYLAND_DISPLAY present on the first attempt (the
# issue #32 env race, gating the #40 UWSM flip).
{
  pkgs,
  inputs ? null,
}: let
  # Stands in for Hyprland inside the uwsm unit graph: brings up a
  # headless compositor, then does exactly what hyprland's
  # `exec-once = uwsm finalize` does — export WAYLAND_DISPLAY into the
  # systemd activation environment and notify wayland-wm@.service so
  # the session target (and everything it wants) proceeds.
  stubCompositor = pkgs.writeShellScriptBin "stub-compositor" ''
    weston --backend=headless --socket=wayland-uwsm &
    weston_pid=$!
    for _ in $(seq 100); do
      [ -S "$XDG_RUNTIME_DIR/wayland-uwsm" ] && break
      sleep 0.1
    done
    export WAYLAND_DISPLAY=wayland-uwsm
    uwsm finalize
    wait $weston_pid
  '';
in
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
      # Separate user for the uwsm round so the manual weston/env state
      # from tester's subtests can't mask an env race.
      users.users.uwsmtester = {
        isNormalUser = true;
        password = "uwsmtester";
      };

      environment.systemPackages = [pkgs.weston stubCompositor];
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

      # ---- uwsm round: the production unit graph, stub compositor ----

      uwsm_uid = machine.succeed("id -u uwsmtester").strip()
      uwsm_run_dir = f"/run/user/{uwsm_uid}"

      def uwsm_user(cmd):
          return machine.succeed(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; {cmd}'"
          )

      with subtest("uwsm session pulls the omarchy units up first-try (issues #32/#40)"):
          # A user-level hyprland.desktop shadows the system session entry,
          # so `uwsm start hyprland.desktop` — the same compositor ID the
          # shipped hyprland-uwsm.desktop session uses — runs the stub
          # instead of real Hyprland. Everything else (wayland-wm@,
          # wayland-session@hyprland.desktop.target, the omarchy wants) is
          # the production graph.
          machine.succeed("loginctl enable-linger uwsmtester")
          machine.wait_until_succeeds(f"test -S {uwsm_run_dir}/bus")
          machine.succeed(
              "su - uwsmtester -c '"
              "mkdir -p ~/.local/share/wayland-sessions && "
              "printf \"[Desktop Entry]\\nName=Hyprland (stub)\\nExec=stub-compositor\\nType=Application\\n\" "
              "> ~/.local/share/wayland-sessions/hyprland.desktop'"
          )
          uwsm_user(
              "systemd-run --user --unit=uwsm-session -- uwsm start hyprland.desktop"
          )
          machine.wait_until_succeeds(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              f"systemctl --user is-active \"{SESSION_TARGET}\"'",
              timeout=60,
          )

          # The env race is the whole point: clipse and wl-clip-persist die
          # instantly without WAYLAND_DISPLAY, so active + zero restarts
          # means the activation environment carried the socket on the
          # very first start. mako is the same but dbus-activated-capable.
          env = uwsm_user("systemctl --user show-environment")
          assert "WAYLAND_DISPLAY=wayland-uwsm" in env, (
              "uwsm finalize should have exported WAYLAND_DISPLAY:\n" + env
          )
          for svc in ("clipse", "wl-clip-persist", "mako"):
              machine.wait_until_succeeds(
                  f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
                  f"systemctl --user is-active {svc}'",
                  timeout=30,
              )
              n_restarts = uwsm_user(
                  f"systemctl --user show -p NRestarts --value {svc}"
              ).strip()
              assert n_restarts == "0", (
                  f"{svc} restarted {n_restarts} time(s) — it must come up "
                  "first-try with WAYLAND_DISPLAY already present (issue #32)"
              )

      with subtest("uwsm stop tears the omarchy units down with the session"):
          uwsm_user("uwsm stop")
          machine.wait_until_fails(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              "systemctl --user is-active clipse'",
              timeout=30,
          )
    '';
  }
