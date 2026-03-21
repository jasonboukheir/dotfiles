{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    environment.systemPackages = with pkgs; [
      gpu-screen-recorder
      gpu-screen-recorder-gtk
      hyprshot
      hyprpicker
      hyprsunset
      brightnessctl
      pamixer
      playerctl
      pavucontrol
      libnotify
      nautilus
      clipse
      (writeShellScriptBin "hyprexit" ''
        ${hyprland}/bin/hyprctl dispatch exit
        ${systemd}/bin/loginctl terminate-user "''$USER"
      '')
      beeper
      supersonic-wayland
    ];
    allowUnfreePackageNames = ["beeper"];
  };
}
