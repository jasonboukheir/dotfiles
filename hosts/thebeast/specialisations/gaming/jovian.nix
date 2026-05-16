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
    jovian.steam.user = cfg.user;
    jovian.steamos.useSteamOSConfig = false;
    jovian.devices.steamdeck.enable = false;
    jovian.hardware.has.amd.gpu = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    programs.gamemode.enable = true;
  }
