{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/nord.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    cursor = {
      name = "Nordzy-cursors";
      package = pkgs.nordzy-cursor-theme;
      size = 18;
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
    icons = {
      enable = true;
      package = pkgs.nordzy-icon-theme;
      light = "Nordzy";
      dark = "Nordzy-dark";
    };
  };
}
