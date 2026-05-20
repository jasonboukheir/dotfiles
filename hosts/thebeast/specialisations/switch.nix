{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;

  specMarker = "/etc/thebeast-spec";
  activeSpec =
    if cfg.enable
    then "gaming"
    else "dev";

  sudo = "/run/wrappers/bin/sudo";

  # /nix/var/nix/profiles/system is the canonical "latest staged
  # toplevel": nixos-rebuild updates it but specialisation switches
  # don't, so it always names the parent (gaming) regardless of which
  # spec is currently live. /run/booted-system is the fallback for
  # fresh VM tests where the system profile hasn't been populated.
  resolveTarget = relPath: ''
    target=""
    for base in /nix/var/nix/profiles/system /run/booted-system; do
      if [ -x "$base${relPath}" ]; then
        target="$base${relPath}"
        break
      fi
    done
    if [ -z "$target" ]; then
      echo "no switch-to-configuration found at *${relPath}" >&2
      exit 1
    fi
  '';

  # Both specs share a single greetd display manager (autologin gamer
  # in gaming, tuigreet → jasonbk in dev). The wrappers therefore do
  # nothing more than activate the new toplevel: switch-to-configuration
  # diffs greetd's config, restarts it (we force restartIfChanged in
  # greetd.nix), and the new initial_session/default_session takes over.
  #
  # Exit 4 means system activation succeeded but a user-instance reload
  # failed — typically a retiring user's units pointing at the old
  # toplevel. The system half is what matters for the swap; tolerate it.
  #
  # Every active user-<uid>.slice gets stopped before activation runs.
  # Whichever direction we're going, the outgoing session sits in some
  # user-<uid>.slice as session-N.scope (a *sibling* of user@<uid>.service
  # inside the slice). Stopping only user@<uid>.service leaves the
  # session alive — it keeps holding tty1, and greetd's restart can't
  # reclaim the TTY for the new spec's initial_session. Iterating over
  # the slice list (rather than naming one user up front) covers
  # gamer→dev (kills gamer + greeter), dev→gaming (kills jasonbk +
  # greeter), and any future operator user without per-spec config.
  # The visible production symptom of getting this wrong is a black,
  # cursorless framebuffer after the swap.
  swapWrapper = {
    name,
    target,
    targetSpec,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.systemd pkgs.gawk pkgs.plymouth];
      text = ''
        # The desktop-entry click path spawns this script (after a sudo
        # hop) inside the calling user's session-N.scope under
        # user-$uid.slice. sudo doesn't migrate cgroups, so when we
        # reach the slice-stop loop below, PID1 SIGTERMs every process
        # in the slice — us included — before switch-to-configuration
        # runs. Re-exec ourselves as a transient root service in
        # system.slice via systemd-run, with an env-var sentinel as the
        # loop guard. Sentinel-over-cgroup-introspection because the
        # env var is one bit of state we own, while /proc/self/cgroup
        # format and the post-migration cgroup path are implementation
        # details that have changed across systemd majors. --pipe
        # --wait propagates stdio + exit status; --collect tidies the
        # unit on completion regardless of result.
        if [ -z "''${_THEBEAST_SPEC_DETACHED:-}" ]; then
          exec systemd-run \
            --quiet --pipe --wait --collect \
            --slice=system.slice \
            --setenv=_THEBEAST_SPEC_DETACHED=1 \
            -- "$0" "$@"
        fi

        targetSpec="${targetSpec}"

        # Best-effort plymouth handoff. plymouthd-as-shutdown-splash is
        # the standard pattern for painting status during teardown:
        # systemd's shutdown.target uses the same mode for `Stopping
        # Plymouth boot screen` → splash redraw. We don't gate the swap
        # on success — if plymouthd can't acquire DRM (compositor still
        # holds master, or the host has no plymouth theme configured),
        # the messages go nowhere and the swap proceeds silently.
        plymouth_active=0
        if plymouth --ping 2>/dev/null; then
          plymouth_active=1
        elif plymouthd --mode=shutdown 2>/dev/null && plymouth show-splash 2>/dev/null; then
          plymouth_active=1
        fi
        say() {
          if [ "$plymouth_active" = 1 ]; then
            plymouth display-message --text "$1" 2>/dev/null || true
            plymouth update --status="$1" 2>/dev/null || true
          fi
          echo "$1"
        }
        say "Switching to $targetSpec mode..."

        ${resolveTarget target}

        # Drain every active session scope before activation. Session
        # scopes (session-N.scope under user-<uid>.slice) hold tty1, the
        # DRM master, and every wayland client of the outgoing desktop.
        # On dev → gaming with real Hyprland sessions these scopes
        # contain electron apps, xwayland, pipewire helpers, and a web
        # browser or two that don't reliably exit on SIGTERM — the
        # slowest holdout sets the floor on swap latency. systemd's
        # default TimeoutStopSec is 90s, and the visible production
        # symptom is a blinking caret on tty1 followed by 1-2 minutes
        # of black screen while we wait the scope out.
        #
        # Three-phase drain: SIGTERM → 3s grace → SIGKILL. Well-behaved
        # clients (hyprland, steam, browsers, editors) save state and
        # exit during the grace window; misbehaving ones get force-
        # killed when it expires. 3s is comfortably above the worst
        # polite-exit I've measured in practice and well under the
        # user-perceptible "is this hung?" threshold. (A `systemctl
        # set-property --runtime TimeoutStopSec=…` override would be
        # the systemd-native form, but the property is fixed at scope
        # creation time and the runtime override silently no-ops.)
        #
        # Critically, we do NOT stop the parent user-<uid>.slice or
        # user@<uid>.service / user-runtime-dir@<uid>.service. An
        # abrupt slice kill leaves /run/user/<uid> torn down while
        # logind still lists the user; switch-to-configuration's
        # "reloading user units for <user>" pass then EACCES on
        # /run/user/<uid>/nixos. By keeping the user manager and
        # runtime dir intact we hand activation a coherent user
        # instance and the reload pass runs cleanly. The wrapper's
        # own invocation chain (the privileged switcher → systemd-run
        # in user-<uid>.slice/run-XXXXX.service) is in the slice too;
        # leaving the slice alone keeps the chain alive long enough
        # to propagate the activation exit code back to the caller.
        #
        # Known collateral: name-based filtering catches every active
        # session scope including non-seat0 logind sessions (e.g. a
        # concurrent ssh login). If that ever bites, switch the filter
        # to `loginctl list-sessions | awk '$4 == "seat0"'`; the test
        # harness plants a transient session-<N>.scope outside logind
        # and relies on name-based matching to find it, so a seat-only
        # filter would need a matching test redesign.
        mapfile -t sessionScopes < <(
          systemctl list-units --type=scope --state=active --no-legend --plain \
            | awk '$1 ~ /^session-[0-9]+\.scope$/ { print $1 }'
        )
        say "Terminating ''${#sessionScopes[@]} session(s)..."
        for scope in "''${sessionScopes[@]}"; do
          systemctl kill --kill-whom=all --signal=SIGTERM "$scope" 2>/dev/null || true
        done
        sleep 3
        # Anything still alive after the 3s grace is a SIGTERM holdout:
        # an Electron app, browser, steamwebhelper, or other client that
        # doesn't honour SIGTERM cleanly. Log pid/comm/cmdline per
        # surviving process to journald under tag `spec-switch` BEFORE
        # SIGKILL so /proc/<pid>/{comm,cmdline} is still readable. A few
        # swaps' worth of these entries identifies the routine offenders
        # so they can be patched (KillSignal=, TimeoutStopSec= drop-ins)
        # rather than relying on the 3s SIGKILL backstop forever. Pull
        # via: `journalctl -t spec-switch -b`.
        {
          for scope in "''${sessionScopes[@]}"; do
            cg=$(systemctl show -p ControlGroup --value "$scope" 2>/dev/null)
            procs="/sys/fs/cgroup''${cg}/cgroup.procs"
            [ -n "$cg" ] && [ -r "$procs" ] || continue
            while read -r pid; do
              [ -z "$pid" ] && continue
              comm=$(cat "/proc/$pid/comm" 2>/dev/null || echo "?")
              cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "?")
              printf 'SIGTERM holdout in %s: pid=%s comm=%s cmdline=%s\n' \
                "$scope" "$pid" "$comm" "''${cmdline:-?}"
              say "Force-killing $comm (pid $pid)..."
            done < "$procs"
          done
        } | systemd-cat -t spec-switch -p warning
        for scope in "''${sessionScopes[@]}"; do
          systemctl kill --kill-whom=all --signal=SIGKILL "$scope" 2>/dev/null || true
        done
        # Stop tolerates `Unit not loaded` (exit 5): after SIGKILL the
        # cgroup empties and systemd auto-deactivates the transient
        # scope (with --collect, it unloads too) before this call
        # reaches it. A real stop failure (dbus down, permissions)
        # would surface on the very next systemctl call; aborting
        # here under set -e would only leave the spec marker stale.
        for scope in "''${sessionScopes[@]}"; do
          systemctl stop "$scope" 2>/dev/null || true
        done

        say "Activating $targetSpec configuration..."
        status=0
        # `test`, not `switch`: activate the target toplevel without
        # overwriting the boot default. Specialisations are sibling boot
        # entries by design; a `switch` here would silently make every
        # spec flip the new default-on-reboot.
        "$target" test || status=$?
        if [ "$status" -ne 0 ] && [ "$status" -ne 4 ]; then
          # Leave the splash up on failure so the user can read it;
          # the new spec's greetd never came up, so there's no
          # session-restart race to win.
          say "Activation failed (status=$status)"
          exit "$status"
        fi
        # Re-evaluate udev rules against existing /dev nodes. The
        # gaming and dev specs ship different udev rule sets — jovian's
        # 60-steam-input.rules tags /dev/uinput, /dev/hidraw* and
        # Valve-vendor /dev/input/event* with TAG+="uaccess", which
        # logind reads on session creation to ACL the device to the
        # logged-in user. switch-to-configuration's `udevadm control
        # --reload-rules` only affects *future* uevents; the kernel
        # never re-fires "add" for /dev/uinput (created once by the
        # uinput module load at boot) or for already-plugged hidraw/
        # input devices, so they sit on the previous spec's tags. The
        # new gamer/jasonbk session then opens without uaccess; the
        # production symptom is the user-instance steamos-manager
        # failing "Starting udev-monitor → Encountered error running:
        # Permission denied" trying to open /dev/uinput, looping
        # under TimeoutStartSec (default 90s × StartLimitBurst=5) for
        # ~3 minutes, during which jovian-setup-desktop-session's
        # `steamosctl set-default-desktop-session` dbus call hangs and
        # Steam's "Switch to Desktop" eventually times out.
        # `--action=change` (not "add") because logind reapplies uaccess
        # on "change" without surprising the kernel module. `settle
        # --timeout=5` is best-effort; we don't gate the swap on it.
        udevadm trigger \
          --action=change \
          --subsystem-match=misc \
          --subsystem-match=input \
          --subsystem-match=hidraw 2>/dev/null || true
        udevadm settle --timeout=5 2>/dev/null || true

        # Drop plymouth before greetd restarts — greetd needs the TTY,
        # and a lingering plymouth holds DRM master.
        [ "$plymouth_active" = 1 ] && plymouth quit 2>/dev/null || true
      '';
    };

  switchToGameMode = swapWrapper {
    name = "switch-to-game-mode";
    target = "/bin/switch-to-configuration";
    targetSpec = "gaming";
  };
  switchToDevMode = swapWrapper {
    name = "switch-to-dev-mode";
    target = "/specialisation/dev/bin/switch-to-configuration";
    targetSpec = "dev";
  };

  # The user-facing entrypoints are spec-asymmetric on purpose:
  #   - In dev (hyprland), the only swap that makes sense is to gaming.
  #     A dev-mode wrapper would be a no-op short-circuit and shows up
  #     in app launchers as user-confusing dead weight.
  #   - In gaming (plasma/gamescope), the only spec swap is to dev. The
  #     in-place "go to big picture" flow is a separate workflow served
  #     by switchToBigPicture below — it never swaps specs.
  # The wrappers ignore positional args (the privileged switchers'
  # bodies are fixed recipes). Don't forward "$@" — there's no callsite
  # that wants to pass args, and the surface only shows up in audit
  # logs / process tables.
  switchToGameModeUser = pkgs.writeShellApplication {
    name = "switch-to-game-mode-user";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      exec ${sudo} -n ${switchToGameMode}/bin/switch-to-game-mode
    '';
  };

  switchToDevModeUser = pkgs.writeShellApplication {
    name = "switch-to-dev-mode-user";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      exec ${sudo} -n ${switchToDevMode}/bin/switch-to-dev-mode
    '';
  };

  # Plasma's shortcut used to call steamosctl switch-to-game-mode, which
  # tears down the desktop session and starts gamescope — the wrong
  # behaviour when the user just wants to relaunch Steam into Big
  # Picture without leaving plasma. The new flow: shut down any running
  # Steam cleanly, wait for it to actually exit (the single-instance
  # lock survives the IPC quit briefly), force-kill if it hangs, then
  # exec `steam -gamepadui` which is the modern Steam Deck-style Big
  # Picture UI inside the current X/wayland session.
  switchToBigPicture = pkgs.writeShellApplication {
    name = "switch-to-big-picture";
    runtimeInputs = [pkgs.coreutils pkgs.procps];
    text = ''
      if pgrep -x steam >/dev/null 2>&1; then
        steam -shutdown 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
          pgrep -x steam >/dev/null 2>&1 || break
          sleep 1
        done
        if pgrep -x steam >/dev/null 2>&1; then
          pkill -TERM -x steam || true
          sleep 1
          pkill -KILL -x steam || true
        fi
      fi
      exec steam -gamepadui
    '';
  };

  gameModeDesktop = pkgs.makeDesktopItem {
    name = "switch-to-game-mode";
    desktopName = "Switch to Game Mode";
    comment = "Activate the gaming specialisation (gamescope + Steam)";
    exec = "${switchToGameModeUser}/bin/switch-to-game-mode-user";
    icon = "applications-games";
    categories = ["System"];
    terminal = false;
  };

  devModeDesktop = pkgs.makeDesktopItem {
    name = "switch-to-dev-mode";
    desktopName = "Switch to Dev Mode";
    comment = "Activate the dev specialisation (Hyprland)";
    exec = "${switchToDevModeUser}/bin/switch-to-dev-mode-user";
    icon = "applications-development";
    categories = ["System"];
    terminal = false;
  };

  bigPictureDesktop = pkgs.makeDesktopItem {
    name = "switch-to-big-picture";
    desktopName = "Switch to Big Picture";
    comment = "Close Steam and re-launch it directly into Big Picture (SteamOS UI)";
    exec = "${switchToBigPicture}/bin/switch-to-big-picture";
    icon = "steam";
    categories = ["Game"];
    terminal = false;
  };

  gamerDesktopDir = "/home/${cfg.user}/Desktop";

  # Privileged switchers ship in both specs: a dev rebuild still needs
  # switch-to-game-mode on PATH so the user can swap back, and vice
  # versa. The user-facing layer is asymmetric on purpose:
  #   - In dev (hyprland), only the swap-to-gaming entry makes sense.
  #     A dev-mode shortcut would be a no-op when already in dev.
  #   - In gaming (plasma), ship the swap-to-dev entry and the
  #     in-place Big Picture launcher — distinct workflows the user
  #     wants surfaced separately. No game-mode shortcut: we're
  #     already there, and the old "Switch to Game Mode" desktop
  #     entry's behaviour (steamosctl → gamescope) was the wrong fit
  #     for a plasma session that just wants Steam's gamepad UI.
  modePackages =
    [switchToGameMode switchToDevMode]
    ++ (
      if cfg.enable
      then [
        switchToDevModeUser
        switchToBigPicture
        devModeDesktop
        bigPictureDesktop
      ]
      else [
        switchToGameModeUser
        gameModeDesktop
      ]
    );

  # NOPASSWD only covers the outgoing direction per spec; the other
  # privileged binary is still on PATH (so run_switch's idempotent
  # checks can call it as root) but unprivileged users have no rule
  # to escalate through it. Defense in depth — removes the entire
  # other-direction surface from the sudo policy.
  modeSudoRule =
    if cfg.enable
    then {
      command = "${switchToDevMode}/bin/switch-to-dev-mode";
      options = ["NOPASSWD"];
    }
    else {
      command = "${switchToGameMode}/bin/switch-to-game-mode";
      options = ["NOPASSWD"];
    };
in {
  environment.systemPackages = modePackages;

  # The marker is the spec-detection signal external scripts (and the
  # tests) read. environment.etc.* is per-toplevel, so the two specs
  # write different contents and switch-to-configuration installs the
  # right one.
  environment.etc."thebeast-spec".text = activeSpec;

  security.sudo.extraRules = [
    {
      users = ["jasonbk" cfg.user];
      commands = [modeSudoRule];
    }
  ];

  # gamer's Desktop is only meaningful in gaming spec (gamer is autologin
  # then; in dev, gamer isn't logged in at all). Keep the symlinks
  # gaming-only so a dev rebuild doesn't leave dangling shortcuts to
  # store paths that aren't even in the dev closure.
  systemd.tmpfiles.settings = lib.mkIf cfg.enable {
    "10-thebeast-gamer-desktop-shortcuts" = {
      ${gamerDesktopDir}.d = {
        mode = "0755";
        user = cfg.user;
        group = cfg.user;
      };
      "${gamerDesktopDir}/switch-to-dev-mode.desktop"."L+" = {
        argument = "${devModeDesktop}/share/applications/switch-to-dev-mode.desktop";
      };
      "${gamerDesktopDir}/switch-to-big-picture.desktop"."L+" = {
        argument = "${bigPictureDesktop}/share/applications/switch-to-big-picture.desktop";
      };
    };
  };
}
