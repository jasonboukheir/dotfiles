# pkgs.helium comes from helium-flake's overlay (only applied on hosts that
# enable this tool). The fixed-path External Extensions manifests under
# ~/.config/net.imput.helium are deliberately NOT baked into the package —
# they're seed-and-accept host state (tmpfiles on NixOS, home.file on the
# standalone-HM hosts until #39 lands).
{
  lib,
  pkgs,
}: {
  name = "helium";
  defaultPackage = "helium";

  build = {
    cfg,
    ...
  }:
    cfg.package;
}
