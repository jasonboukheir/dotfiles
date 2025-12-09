{
  config,
  pkgs,
  ...
}: let
  gameUser = "jasonbk";
  plasma = config.services.desktopManager.plasma6;
  hyprland = config.programs.hyprland;
  session =
    if plasma.enable
    then "plasma"
    else if hyprland.enable
    then "hyprland"
    else null;
in {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = gameUser;
    desktopSession = session;
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
  programs.steam.stylix.enable = config.stylix.enable;
}
