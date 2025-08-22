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
    programs.nushell = {
      extraLogin = builtins.readFile ./extraLogin.nu;
    };
  };
}
