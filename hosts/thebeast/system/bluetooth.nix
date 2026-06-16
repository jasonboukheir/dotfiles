{...}: {
  hardware.bluetooth.enable = true;

  # Keep blueman for the manager GUI (waybar's bluetooth module opens
  # blueman-manager on click), but suppress its xdg-autostart applet: it
  # duplicates waybar's own bluetooth tray icon and emits connect/disconnect
  # notification spam whenever a trusted device (e.g. multipoint headphones
  # bouncing between hosts) is reachable but refuses A2DP.
  services.blueman.enable = true;
  systemd.user.services."app-blueman@autostart".enable = false;
}
