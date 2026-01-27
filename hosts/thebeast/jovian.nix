{
  config,
  pkgs,
  ...
}: let
  gameUser = "gamer";
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
    autoStart = false;
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
  users.users."${gameUser}" = {
    isNormalUser = true;
    description = "Steam Console";
    extraGroups = ["networkmanager" "gamemode" "input"];
    initialPassword = "";
  };
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings.General.InputMethod = "qtvirtualkeyboard";
  };
  services.displayManager.autoLogin = {
    enable = true;
    user = gameUser;
  };
  services.displayManager.defaultSession = "gamescope-wayland";
  systemd.tmpfiles.rules = [
    "f /var/lib/AccountService/users/jasonbk 0644 root root - [User]\nSession=${session}\n"
  ];
}
