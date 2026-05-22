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
      # `hyprctl dispatch exit` alone leaves the session in a half-torn-down
      # state on hosts running plasma-login-manager: hyprland's wayland
      # compositor exits, but logind still has the user session open and the
      # greeter never repaints, leaving a black framebuffer. Going straight
      # through logind closes the session cleanly so display-manager.service
      # (Restart=always) brings the greeter back. terminate-user kills hyprland
      # as a side effect, so no explicit dispatch is needed.
      (writeShellScriptBin "hyprexit" ''
        exec ${systemd}/bin/loginctl terminate-user "''$USER"
      '')
      beeper
      supersonic-wayland
    ];
    allowUnfreePackageNames = ["beeper"];
  };
}
