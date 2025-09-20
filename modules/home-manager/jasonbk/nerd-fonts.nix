{
  config,
  lib,
  pkgs,
  ...
}: {
  options = {
    nerd-fonts.enable = lib.mkEnableOption "Nerd Fonts";
  };
  config = {
    nerd-fonts.enable = lib.mkDefault true;
    home.packages = lib.optionals config.nerd-fonts.enable [pkgs.nerd-fonts.fira-code];
  };
}
