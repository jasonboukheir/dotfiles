{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.nushell;
in {
  config = mkIf cfg.enable {
    envFile.source = ./env.nu;
  };
}
