{pkgs, ...}: {
  home-manager.users.jasonbk = {
    home.packages = [pkgs.discord];
    home.file = {
      ".config/discord" = {
        source = ./discord;
        recursive = true;
      };
    };
  };
}
