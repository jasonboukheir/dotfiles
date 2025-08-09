{ config, lib, options, pkgs, ... }:
{
  options = {
    fonts.enable = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable fonts";
    };
  };
  config = lib.mkIf config.fonts.enable {
    home.packages = with pkgs; [
      nerd-fonts.fira-code
    ];
  };
}
