{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.gmx = {
    enable = lib.mkEnableOption "gmx (Ghostty multiplexer with zmx session persistence)";
  };

  config = lib.mkIf config.programs.gmx.enable {
    home.packages =
      [pkgs.zmx]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [pkgs.gmx];
  };
}
