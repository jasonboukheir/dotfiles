{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.eternal-terminal = {
    enable = lib.mkEnableOption "Eternal Terminal client (et)";
  };

  config = lib.mkIf config.programs.eternal-terminal.enable {
    home.packages = [pkgs.eternal-terminal];
  };
}
