{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming;

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
  swapWrapper = {
    name,
    target,
    retireUser,
  }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.coreutils pkgs.systemd];
      text = ''
        ${resolveTarget target}

        if uid=$(id -u ${lib.escapeShellArg retireUser} 2>/dev/null) \
            && systemctl is-active --quiet "user@$uid.service"; then
          # systemctl stop blocks until user@$uid.service reaches inactive,
          # which is when logind unregisters the user object.
          systemctl stop "user@$uid.service" || :
        fi

        status=0
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
  # right one based on /run/current-system.
  switchToGameModeUser = pkgs.writeShellApplication {
    name = "switch-to-game-mode-user";
    runtimeInputs = [pkgs.coreutils pkgs.steamos-manager];
    text = ''
      current=$(readlink -f /run/current-system 2>/dev/null || true)
      case "$current" in
        */specialisation/*)
          exec sudo -n ${switchToGameMode}/bin/switch-to-game-mode "$@"
          ;;
        *)
          exec steamosctl switch-to-game-mode "$@"
          ;;
      esac
    '';
  };

  switchToDevModeUser = pkgs.writeShellApplication {
    name = "switch-to-dev-mode-user";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      current=$(readlink -f /run/current-system 2>/dev/null || true)
      case "$current" in
        */specialisation/dev*)
          echo "Already in dev mode" >&2
          exit 0
          ;;
        *)
          exec sudo -n ${switchToDevMode}/bin/switch-to-dev-mode "$@"
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
  environment.systemPackages = [
    switchToGameMode
    switchToDevMode
    switchToGameModeUser
    switchToDevModeUser
    gameModeDesktop
    devModeDesktop
  ];

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

  systemd.tmpfiles.settings."10-thebeast-gamer-desktop-shortcuts" = lib.mkIf cfg.enable {
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
