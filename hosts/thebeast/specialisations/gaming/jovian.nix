{
  config,
  ...
}: let
  cfg = config.gaming;
in {
  gaming.user = "gamer";

  jovian.steam.enable = true;
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
