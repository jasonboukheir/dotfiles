{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nushell;
in {
  options.programs.nushell.enable = lib.mkEnableOption "Nushell";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nushell
    ];
  };
}
