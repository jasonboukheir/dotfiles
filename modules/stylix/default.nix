{pkgs, ...}: {
  stylix = {
    image = ./wallpapers/vaporwave-dolphins.jpg;
    # base16Scheme = ./themes/eastern-orthodox.yaml;
    base16Scheme = ./themes/analog-dreams.yaml;
    polarity = "dark";
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
    };
  };
}
