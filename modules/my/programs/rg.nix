# rg program definition. See ./CONTRACT.md.
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
