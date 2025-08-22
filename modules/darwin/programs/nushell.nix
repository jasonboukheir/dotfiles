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
    programs.bash.enable = true;
    environment.shells = with pkgs; [nushell zsh];
  };
}
