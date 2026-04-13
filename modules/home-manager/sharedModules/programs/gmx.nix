{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.gmx = {
    enable = lib.mkEnableOption "gmx (Ghostty multiplexer with zmx session persistence)";
    package = lib.mkPackageOption pkgs "gmx" {};
    zmxPackage = lib.mkPackageOption pkgs "zmx" {};
  };

  config = lib.mkIf config.programs.gmx.enable {
    home.packages =
      [config.programs.gmx.zmxPackage]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [config.programs.gmx.package];
  };
}
