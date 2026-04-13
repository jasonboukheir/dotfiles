{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.eternal-terminal = {
    enable = lib.mkEnableOption "Eternal Terminal client (et)";
    package = lib.mkPackageOption pkgs "eternal-terminal" {};
  };

  config = lib.mkIf config.programs.eternal-terminal.enable {
    home.packages = [config.programs.eternal-terminal.package];
  };
}
