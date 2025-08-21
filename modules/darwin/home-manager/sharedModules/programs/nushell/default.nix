{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.nushell;
in {
  config = mkIf cfg.enable {
    programs.nushell.extraEnv = builtins.readFile ./env.nu;
  };
}
