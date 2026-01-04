{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    environment.systemPackages = with pkgs; [
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
