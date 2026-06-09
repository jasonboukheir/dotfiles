{
  lib,
  pkgs,
}: {
  name = "rg";
  defaultPackage = "ripgrep";

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
