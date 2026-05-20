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
  # failed — typically gamer's user units pointing at the old toplevel.
  # The system half is what matters for the swap; tolerate it.
  #
  # `retireUser` names the user whose session belongs to the outgoing
  # spec and must be torn down before switch-to-configuration enumerates
  # logged-in users via logind.ListUsers. Without that, the snapshot
  # includes user@$uid for the retiring user, the per-user activation
  # blocks waiting for its services to stop, logind GCs the user object
  # in the meantime, and the next loop iteration trips
  # `Failed to get GID for <name> / Unknown object login1/user/_<uid>`,
  # which exits 1.
  #
  # We stop user-$uid.slice rather than user@$uid.service: plasma and
  # the rest of the desktop session live in session-<n>.scope, a
  # *sibling* of user@$uid.service inside user-$uid.slice. Stopping
  # only user@$uid.service leaves plasma alive, which holds tty1 and
  # blocks tuigreet from claiming it after greetd restarts — the user
  # is left staring at a blinking underscore on tty1 instead of the
  # dev greeter.
  swapWrapper = {
    name,
    target,
    retireUser,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.systemd];
      text = ''
        # The desktop-entry click path spawns this script (after a sudo
        # hop) inside the calling user's session-N.scope under
        # user-$uid.slice. sudo doesn't migrate cgroups, so when we
        # reach `systemctl stop user-$uid.slice` below, PID1 SIGTERMs
        # every process in the slice — us included — before
        # switch-to-configuration runs. Plasma dies, the framebuffer
        # reverts to the kernel console, the spec marker stays put.
        #
        # Re-exec ourselves as a transient root service in system.slice
        # via systemd-run, with an env-var sentinel as the loop guard.
        # Sentinel-over-cgroup-introspection because the env var is one
        # bit of state we own, while /proc/self/cgroup format and the
        # post-migration cgroup path are implementation details that
        # have changed across systemd majors. --pipe --wait propagates
        # stdio + exit status; --collect tidies the unit on completion
        # regardless of result.
        if [ -z "''${_THEBEAST_SPEC_DETACHED:-}" ]; then
          exec systemd-run \
            --quiet --pipe --wait --collect \
            --slice=system.slice \
            --setenv=_THEBEAST_SPEC_DETACHED=1 \
            -- "$0" "$@"
        fi

        ${resolveTarget target}

        if uid=$(id -u ${lib.escapeShellArg retireUser} 2>/dev/null) \
            && systemctl is-active --quiet "user-$uid.slice"; then
          # systemctl stop on the slice blocks until every unit inside
          # (user@$uid.service + every session-<n>.scope) reaches
          # inactive, at which point logind unregisters the user. If
          # stop itself fails (dbus/permissions/timeout), the logind
          # race described above is back — abort instead of papering
          # over.
          systemctl stop "user-$uid.slice"
        fi

        status=0
        # `test`, not `switch`: activate the target toplevel without
        # overwriting the boot default. Specialisations are sibling boot
        # entries by design; a `switch` here would silently make every
        # spec flip the new default-on-reboot.
        "$target" test || status=$?
        if [ "$status" -ne 0 ] && [ "$status" -ne 4 ]; then
          exit "$status"
        fi
      '';
    };

  switchToGameMode = swapWrapper {
    name = "switch-to-game-mode";
    target = "/bin/switch-to-configuration";
    retireUser = "greeter";
  };
  switchToDevMode = swapWrapper {
    name = "switch-to-dev-mode";
    target = "/specialisation/dev/bin/switch-to-configuration";
    retireUser = cfg.user;
  };

  # The user-facing entrypoints have to handle two distinct cases. The
  # spec swap (dev <-> gaming) reconfigures the whole DM/session graph
  # and needs root; the gamescope <-> plasma toggle inside the gaming
  # spec is steamos-manager's job and runs in the user session against
  # its DBus. A single desktop entry per direction dispatches to the
  # right one based on the spec marker installed alongside the toplevel
  # — readlink /run/current-system can't tell us this because a resolved
  # toplevel is `/nix/store/...-nixos-system-...` regardless of which
  # spec is live.
  readSpec = ''
    spec=$(cat ${specMarker} 2>/dev/null || true)
  '';

  # The privileged switchers ignore positional args (their body is a fixed
  # `switch-to-configuration test` recipe). Don't forward `"$@"` from the
  # user wrappers — there's no callsite that wants to pass args, and the
  # surface only shows up in audit logs / process tables.
  switchToGameModeUser = pkgs.writeShellApplication {
    name = "switch-to-game-mode-user";
    runtimeInputs = [pkgs.coreutils pkgs.steamos-manager];
    text = ''
      ${readSpec}
      case "$spec" in
        dev)
          exec ${sudo} -n ${switchToGameMode}/bin/switch-to-game-mode
          ;;
        *)
          exec steamosctl switch-to-game-mode
          ;;
      esac
    '';
  };

  switchToDevModeUser = pkgs.writeShellApplication {
    name = "switch-to-dev-mode-user";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      ${readSpec}
      case "$spec" in
        dev)
          echo "Already in dev mode" >&2
          exit 0
          ;;
        *)
          exec ${sudo} -n ${switchToDevMode}/bin/switch-to-dev-mode
          ;;
      esac
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

  gamerDesktopDir = "/home/${cfg.user}/Desktop";
in {
  # switchToGameModeUser threads pkgs.steamos-manager onto PATH for the
  # gamescope-side branch. The wrappers ship in both specs (you need them
  # to swap back from dev), so the jovian closure they pull in is reachable
  # even when gaming.enable is false — the gaming spec's own allowlist
  # (specialisations/gaming/jovian.nix) can't cover this one.
  allowUnfreePackageNames = ["steam-jupiter-unwrapped"];

  environment.systemPackages = [
    switchToGameMode
    switchToDevMode
    switchToGameModeUser
    switchToDevModeUser
    gameModeDesktop
    devModeDesktop
  ];

  # The marker is the spec-detection signal the user wrappers read.
  # It must change between the parent toplevel and the dev specialisation
  # — environment.etc.* is per-toplevel, so the two write different
  # contents and switch-to-configuration installs the right one.
  environment.etc."thebeast-spec".text = activeSpec;

  security.sudo.extraRules = [
    {
      users = ["jasonbk" cfg.user];
      commands = [
        {
          command = "${switchToGameMode}/bin/switch-to-game-mode";
          options = ["NOPASSWD"];
        }
        {
          command = "${switchToDevMode}/bin/switch-to-dev-mode";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # Unconditional: a dev rebuild must refresh these symlinks too, or
  # they keep pointing at the previous gaming generation's store paths
  # until the next swap.
  systemd.tmpfiles.settings."10-thebeast-gamer-desktop-shortcuts" = {
    ${gamerDesktopDir}.d = {
      mode = "0755";
      user = cfg.user;
      group = cfg.user;
    };
    "${gamerDesktopDir}/switch-to-dev-mode.desktop"."L+" = {
      argument = "${devModeDesktop}/share/applications/switch-to-dev-mode.desktop";
    };
    "${gamerDesktopDir}/switch-to-game-mode.desktop"."L+" = {
      argument = "${gameModeDesktop}/share/applications/switch-to-game-mode.desktop";
    };
  };
}
