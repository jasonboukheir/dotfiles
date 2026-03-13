{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.stylix;
in {
  config = lib.mkIf cfg.enable {
    stylix = {
      image = ./wallpapers/analog-dreams.jpeg;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      # base16Scheme = ./themes/analog-dreams.yaml;
      polarity = "dark";
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-code;
          name = "FiraCode Nerd Font";
        };
      };
    };
  };
}
