{
  lib,
  pkgs,
}: {
  name = "zmx";
  # pkgs.zmx comes from modules/nixpkgs/overlays/zmx.nix.
  defaultPackage = "zmx";

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
