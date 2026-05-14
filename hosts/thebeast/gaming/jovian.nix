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
    # autoStart wires up SDDM with autoLogin to gamer, the temporary-session
    # mechanism Steam uses to round-trip into Plasma, steamos-manager, and
    # xdg-desktop-portal config. Plasma's "Switch User" action drops to the
    # SDDM greeter on a fresh VT, which is how jasonbk gets into dev.
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
