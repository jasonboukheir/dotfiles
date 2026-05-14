{
  config,
  lib,
  ...
}: let
  cfg = config.gaming;
in
  lib.mkIf config.gaming.enable {
    gaming.user = "gamer";

    jovian.steam.enable = true;
    # autoStart wires up steamos-manager, the "Switch to Desktop" hook, the
    # gamescope-session user-unit env (PATH/XKB), and xdg-desktop-portal config.
    # The SDDM/autoLogin bits it also enables are overridden by ../greetd.nix
    # so greetd owns the display manager seat.
    jovian.steam.autoStart = true;
    jovian.steam.user = cfg.user;
    jovian.steam.desktopSession = "plasma";
    jovian.steamos.useSteamOSConfig = false;
    jovian.devices.steamdeck.enable = false;
    jovian.hardware.has.amd.gpu = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    services.desktopManager.plasma6.enable = true;
  }
