{
  config,
  lib,
  ...
}: {
  programs.hyprland.enable = lib.mkDefault config.omarchy.enable;
  # uwsm-managed Hyprland starts graphical-session.target properly, which is
  # what the home-manager user services (hyprpolkitagent, hypridle, waybar,
  # ...) bind to. Without it, SDDM-launched plain Hyprland sessions can fail
  # before any user service has a chance to start.
  programs.hyprland.withUWSM = lib.mkDefault config.omarchy.enable;
}
