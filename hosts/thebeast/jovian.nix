{pkgs, ...}: let
  gameUser = "gamer";
in {
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

  security.pam.services.greetd.enableGnomeKeyring = true;

  #
  # Steam
  #
  # Set game launcher: gamemoderun %command%
  #   Set this for each game in Steam, if the game could benefit from a minor
  #   performance tweak: YOUR_GAME > Properties > General > Launch > Options
  #   It's a modest tweak that may not be needed. Jovian is optimized for
  #   high performance by default.
  # programs.gamemode = {
  #   enable = true;
  #   settings = {
  #     general = {
  #       renice = 10;
  #     };
  #     gpu = {
  #       apply_gpu_optimisations = "accept-responsibility"; # For systems with AMD GPUs
  #       gpu_device = 0;
  #       amd_performance_level = "high";
  #     };
  #   };
  # };

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
