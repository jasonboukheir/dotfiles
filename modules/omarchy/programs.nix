{
  config,
  lib,
  ...
}: {
  programs.hyprland.enable = lib.mkDefault config.omarchy.enable;
}
