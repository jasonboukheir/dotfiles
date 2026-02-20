{pkgs, ...}: let
  gameUser = "gamer";
in {
  # Ensure the gamer home directory exists on the games drive
  systemd.tmpfiles.rules = [
    "d /games/home/gamer 0755 ${gameUser} ${gameUser} -"
  ];
  jovian.steam.enable = true;
  jovian.steamos.useSteamOSConfig = false;
  jovian.devices.steamdeck.enable = false;
  jovian.hardware.has.amd.gpu = true;

  environment.systemPackages = with pkgs; [
    cmake
    steam-rom-manager
    gamescope
    mangohud
    protonup-qt
    hyprland
  ];
  services.displayManager.sessionPackages = [pkgs.hyprland];
  programs.regreet.enable = true;
  services.greetd.settings.initial_session = {
    command = "start-gamescope-session";
    user = "${gameUser}";
  };

  users = {
    groups.${gameUser} = {
      name = "${gameUser}";
    };

    users.${gameUser} = {
      description = "${gameUser}";
      extraGroups = ["gamemode" "networkmanager" "input"];
      group = "${gameUser}";
      home = "/home/${gameUser}";
      isNormalUser = true;
    };
    users.jasonbk = {
      extraGroups = ["gamemode" "networkmanager" "input"];
    };
  };
}
