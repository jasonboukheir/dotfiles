{...}: {
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # "dropbox-cli start"  # Uncomment to run Dropbox
    ];

    exec = [
      # "pkill -SIGUSR2 waybar || waybar"
    ];
  };
}
