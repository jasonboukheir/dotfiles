{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/analog-dreams.jpeg;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    # base16Scheme = ./themes/eastern-orthodox.yaml;
    polarity = "dark";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
