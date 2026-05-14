{
  config,
  pkgs,
  lib,
  ...
}: let
  startGamescope = "${pkgs.gamescope-session}/bin/start-gamescope-session";
  gamerUser = config.gaming.user;
  sessions = config.services.displayManager.sessionData.desktops;
in {
  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;

  programs.regreet.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = startGamescope;
        user = gamerUser;
      };
      # default_session.command is set by the regreet module via mkDefault.
      default_session.user = "greeter";
    };
  };

  # regreet discovers sessions via XDG_DATA_DIRS — point it at the merged
  # wayland-sessions + xsessions tree NixOS assembles from sessionPackages.
  systemd.services.greetd = {
    environment.XDG_DATA_DIRS = "${sessions}/share";
    serviceConfig = {
      Type = "idle";
      StandardError = "journal";
    };
  };
}
