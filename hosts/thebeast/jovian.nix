{pkgs, ...}: let
  gameUser = "jasonbk";
in {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = gameUser;
    desktopSession = "hyprland";
  };
  jovian.steamos = {
    enableZram = false;
    enableEarlyOOM = false;
  };
  jovian.devices.steamdeck.enable = false;
  jovian.hardware.has.amd.gpu = true;
  environment.systemPackages = with pkgs; [
    gamescope
    mangohud
    protonup-qt
  ];
  users.users."${gameUser}".extraGroups = ["gamemode" "networkmanager"];
}
