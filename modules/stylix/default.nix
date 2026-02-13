{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/nord.jpg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    polarity = "dark";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
