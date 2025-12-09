{
  config,
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs;
    lib.optionals config.omarchy.enable [
      hyprshot
      hyprpicker
      hyprsunset
      brightnessctl
      pamixer
      playerctl
      pavucontrol
      libnotify
      nautilus
      blueberry
      clipse
    ];
}
