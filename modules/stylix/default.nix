{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/batou.jpg;
    # base16Scheme = ./themes/eastern-orthodox.yaml;
    base16Scheme = ./themes/batou.yaml;
    polarity = "dark";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
