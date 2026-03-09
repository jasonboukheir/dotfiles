{pkgs, ...}: let
  gameUser = "gamer";
in {
  jovian.steam.enable = true;
  jovian.steam.autoStart = true;
  jovian.steam.user = "${gameUser}";
  jovian.steam.desktopSession = "plasma";
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
  jovian.steamos.useSteamOSConfig = false;
  jovian.devices.steamdeck.enable = false;
  jovian.hardware.has.amd.gpu = true;

  environment.systemPackages = with pkgs; [
    cmake
    steam-rom-manager
    gamescope
    mangohud
    protonup-qt
  ];
  services.desktopManager.plasma6.enable = true;
}
