{ config, lib, options, pkgs, ... }:
{
  options = {
    programs.nix.formatters.enable = lib.mkEnableOption "Enable Nix formatters";
  };

  config = lib.mkIf config.programs.nix.formatters.enable {
    home.packages = with pkgs; [
      nil
      nixd
      nixfmt-rfc-style
    ];
  };
}
