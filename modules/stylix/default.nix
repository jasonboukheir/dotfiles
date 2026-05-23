{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.stylix;
  wallpapers = import ./wallpapers {inherit pkgs;};
in {
  config = lib.mkIf cfg.enable {
    stylix = {
      image = wallpapers.vaporwave-neon-nightscape;
      # base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      base16Scheme = ./themes/digital-nightmares.yaml;
      polarity = "dark";
      opacity.terminal = 0.97;
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-code;
          name = "FiraCode Nerd Font";
        };
      };
      targets = {
        nvf.plugin = "mini-base16";
      };
    };
  };
}
