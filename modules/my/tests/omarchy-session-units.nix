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

      with subtest("clipse starts and stays active"):
          user("systemctl --user start clipse")
          machine.wait_until_succeeds(
              f"su - tester -c 'export XDG_RUNTIME_DIR={run_dir}; "
              "systemctl --user is-active clipse'"
          )

      with subtest("wl-clip-persist launches with the wayland env delivered"):
          # Headless weston exposes no {ext,zwlr}-data-control global, so
          # wl-clip-persist can never stay up here (under real Hyprland's
          # wlroots protocols it does); it crash-loops into its start rate
          # limit. Reaching the missing-protocol error proves the unit got
          # WAYLAND_DISPLAY — failing to connect at all would mean it didn't.
          machine.execute(
              f"su - tester -c 'export XDG_RUNTIME_DIR={run_dir}; "
              "systemctl --user start wl-clip-persist || true'"
          )
          # _UID instead of --user-unit: the user-unit match comes up empty in
          # these test VMs (even as an explicit _SYSTEMD_USER_UNIT= field), so
          # filter by uid and grep the syslog-identified lines.
          machine.wait_until_succeeds(
              f"journalctl _UID={uid} "
              "| grep -q 'Failed to get clipboard manager'"
          )
          journal = machine.succeed(f"journalctl _UID={uid} | grep wl-clip-persist")
          assert "Failed to connect to wayland server" not in journal, journal

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
          # grep for the unit name, not '.': --user-unit matches nothing in
          # these VMs, and journalctl's literal "-- No entries --" output
          # would satisfy a match-anything grep vacuously.
          machine.wait_until_succeeds(
              f"journalctl _UID={uid} | grep -q 'hyprsunset.service'"
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
          # uwsm >= 0.26 requires the login session identity (XDG_SESSION_ID/
          # XDG_SEAT/XDG_VTNR) in `uwsm start`'s environment — production gets
          # them from the display manager's PAM stack; without them the env
          # preloader falls back to logind VT deduction, which has no session
          # to find under this linger-only user manager and kills the graph.
          uwsm_user(
              "systemd-run --user --unit=uwsm-session "
              "--setenv=XDG_SESSION_ID=1 --setenv=XDG_SEAT=seat0 --setenv=XDG_VTNR=1 "
              "-- uwsm start hyprland.desktop"
          )
          machine.wait_until_succeeds(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              f"systemctl --user is-active \"{SESSION_TARGET}\"'",
              timeout=60,
          )

          env = uwsm_user("systemctl --user show-environment")
          assert "WAYLAND_DISPLAY=wayland-uwsm" in env, (
              "uwsm finalize should have exported WAYLAND_DISPLAY:\n" + env
          )
          machine.wait_until_succeeds(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              "systemctl --user is-active clipse'",
              timeout=30,
          )

          # The env race is the whole point (issue #32), but headless weston
          # can't keep the wlroots-protocol clients alive: wl-clip-persist
          # needs a data-control global and mako needs zwlr_layer_shell_v1
          # (both exist under real Hyprland). Each missing-protocol error
          # still only happens once the client has already connected to
          # WAYLAND_DISPLAY, so reaching it on the very first start — and
          # never the connect-time error — proves the activation environment
          # carried the socket from the start.
          env_race_canaries = {
              "wl-clip-persist": (
                  "Failed to get clipboard manager",
                  "Failed to connect to wayland server",
              ),
              "mako": (
                  "compositor doesn't support zwlr_layer_shell_v1",
                  "failed to connect to display",
              ),
          }
          for svc, (protocol_err, connect_err) in env_race_canaries.items():
              machine.wait_until_succeeds(
                  f"journalctl _UID={uwsm_uid} | grep -q \"{protocol_err}\"",
                  timeout=30,
              )
              journal = machine.succeed(f"journalctl _UID={uwsm_uid} | grep {svc}")
              assert connect_err not in journal, (
                  f"{svc} started without WAYLAND_DISPLAY (issue #32):\n" + journal
              )

      with subtest("oom-policy drop-in reaches uwsm's package-shipped unit"):
          # The template drop-in must merge into the running instance of the
          # uwsm package's wayland-wm@.service — otherwise one kernel OOM
          # kill inside the compositor cgroup stops the unit and tears the
          # whole session down (OOMPolicy=stop default).
          oom = uwsm_user(
              "systemctl --user show -p OOMPolicy wayland-wm@hyprland.desktop.service"
          ).strip()
          assert oom == "OOMPolicy=continue", oom

      with subtest("uwsm app launches escape the compositor unit's cgroup"):
          # What the launch/launchLocal keybinding helpers rely on: the
          # launched app gets its own transient scope instead of living (and
          # being OOM-accounted) inside wayland-wm@'s cgroup.
          uwsm_user(
              "systemd-run --user --unit=uwsm-app-probe -- uwsm app -- sleep 600"
          )
          # uwsm resolves the command through $PATH, so the spawned process is
          # "/…/bin/sleep 600", not a bare "sleep 600"; match the path-qualified
          # cmdline (an -fx exact match on "sleep 600" can never land).
          probe = r"-u uwsmtester -fx '.*/sleep 600'"
          machine.wait_until_succeeds(f"pgrep {probe}")
          cgroup = machine.succeed(f"cat /proc/$(pgrep {probe})/cgroup")
          assert "wayland-wm@" not in cgroup, cgroup
          assert ".scope" in cgroup, cgroup
          machine.succeed(f"pkill {probe}")

      with subtest("uwsm stop tears the omarchy units down with the session"):
          # Stopping while session activation jobs are still queued is
          # refused as a destructive transaction; let the graph settle.
          machine.wait_until_succeeds(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              "systemctl --user list-jobs | grep -q \"No jobs\"'",
              timeout=30,
          )
          uwsm_user("uwsm stop")
          machine.wait_until_fails(
              f"su - uwsmtester -c 'export XDG_RUNTIME_DIR={uwsm_run_dir}; "
              "systemctl --user is-active clipse'",
              timeout=30,
          )
    '';
  }
