{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.nushell;
in {
  config = mkIf cfg.enable {
    environment.shells = [ pkgs.nushell ];
  };
}
