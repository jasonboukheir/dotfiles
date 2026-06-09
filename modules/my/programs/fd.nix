# fd program definition. See ./CONTRACT.md.
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
