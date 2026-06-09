{
  lib,
  pkgs,
}: {
  name = "fd";
  defaultPackage = "fd";

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
