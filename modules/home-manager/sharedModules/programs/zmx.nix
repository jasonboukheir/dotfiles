{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.zmx = {
    enable = lib.mkEnableOption "zmx (session persistence for terminal processes)";
    package = lib.mkPackageOption pkgs "zmx" {};
  };

  config = lib.mkIf config.programs.zmx.enable {
    home.packages = [config.programs.zmx.package];
  };
}
