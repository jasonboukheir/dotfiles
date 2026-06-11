{
  lib,
  pkgs,
}: {
  name = "rga";
  defaultPackage = "ripgrep-all";

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
