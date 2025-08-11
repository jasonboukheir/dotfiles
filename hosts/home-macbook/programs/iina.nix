{pkgs, ...}: {
  home-manager.users.jasonbk = {
    home.packages = [pkgs.iina];
  };
}
