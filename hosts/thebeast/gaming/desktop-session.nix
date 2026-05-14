{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.gaming.enable {
  environment.systemPackages = [pkgs.maliit-keyboard];
}
