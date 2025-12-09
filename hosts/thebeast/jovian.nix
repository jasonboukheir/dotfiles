{pkgs, ...}: let
  gameUser = "jasonbk";
in {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = gameUser;
    desktopSession = "plasma";
  };
  jovian.steamos = {
    useSteamOSConfig = false;
  };
  jovian.devices.steamdeck.enable = false;
  jovian.hardware.has.amd.gpu = true;
  environment.systemPackages = with pkgs; [
    gamescope
    mangohud
    protonup-qt
  ];
  users.users."${gameUser}".extraGroups = ["gamemode" "networkmanager" "input"];
}
