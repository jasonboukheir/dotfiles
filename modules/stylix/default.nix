{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/tree-of-life.jpg;
    base16Scheme = ./themes/eastern-orthodox.yaml;
    polarity = "dark";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
