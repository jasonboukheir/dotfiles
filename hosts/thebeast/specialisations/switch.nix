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

  # NixOS' switch-to-configuration preserves display-manager.service
  # across activations to avoid yanking the running session. That's
  # the wrong UX for a deliberate spec swap — "Switch to Dev Mode"
  # needs to actually tear down Plasma/Steam and hand VT 1 to greetd.
  # The wrappers explicitly stop the *other* mode's entrypoint before
  # activating, and start the new one after.
  #
  # Exit 4 from switch-to-configuration means system activation
  # succeeded but a user-instance reload failed (stale dbus/gamescope
  # user units pointing at the old toplevel). We tolerate it.
  switchToGameMode = pkgs.writeShellApplication {
    name = "switch-to-game-mode";
    text = ''
      ${resolveTarget "/bin/switch-to-configuration"}
      systemctl stop greetd.service 2>/dev/null || true
      status=0
      "$target" test || status=$?
      if [ "$status" -ne 0 ] && [ "$status" -ne 4 ]; then
        exit "$status"
      fi
      systemctl start display-manager.service 2>/dev/null || true
    '';
  };

  switchToDevMode = pkgs.writeShellApplication {
    name = "switch-to-dev-mode";
    text = ''
      ${resolveTarget "/specialisation/dev/bin/switch-to-configuration"}
      systemctl stop display-manager.service 2>/dev/null || true
      loginctl terminate-user ${cfg.user} 2>/dev/null || true
      status=0
      "$target" test || status=$?
      if [ "$status" -ne 0 ] && [ "$status" -ne 4 ]; then
        exit "$status"
      fi
      systemctl start greetd.service 2>/dev/null || true
    '';
  };

  switchToGameModeUser = pkgs.writeShellApplication {
    name = "switch-to-game-mode-user";
    text = ''exec sudo -n ${switchToGameMode}/bin/switch-to-game-mode "$@"'';
  };
  switchToDevModeUser = pkgs.writeShellApplication {
    name = "switch-to-dev-mode-user";
    text = ''exec sudo -n ${switchToDevMode}/bin/switch-to-dev-mode "$@"'';
  };

  returnToSteam = pkgs.writeShellApplication {
    name = "return-to-steam-bigpicture";
    runtimeInputs = [pkgs.steam];
    text = ''exec steam -gamepadui "$@"'';
  };

  gameModeDesktop = pkgs.makeDesktopItem {
    name = "switch-to-game-mode";
    desktopName = "Switch to Game Mode";
    comment = "Activate the gaming specialisation (Plasma + Steam)";
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

  returnToSteamDesktop = pkgs.makeDesktopItem {
    name = "return-to-steam-bigpicture";
    desktopName = "Return to Steam";
    comment = "Re-open Steam in Big Picture mode";
    exec = "${returnToSteam}/bin/return-to-steam-bigpicture";
    icon = "steam";
    categories = ["Game"];
    terminal = false;
  };

  gamerDesktopDir = "/home/${cfg.user}/Desktop";
in {
  environment.systemPackages = [
    switchToGameMode
    switchToDevMode
    switchToGameModeUser
    switchToDevModeUser
    returnToSteam
    gameModeDesktop
    devModeDesktop
    returnToSteamDesktop
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
    "${gamerDesktopDir}/return-to-steam-bigpicture.desktop"."L+" = {
      argument = "${returnToSteamDesktop}/share/applications/return-to-steam-bigpicture.desktop";
    };
  };
}
