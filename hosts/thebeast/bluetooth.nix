{...}: {
  hardware.bluetooth.enable = true;

  services.blueman = {
    enable = true;
    # TODO: drop withApplet override when https://github.com/NixOS/nixpkgs/issues/514705 is fixed.
    # The NixOS-managed override unit adds a second ExecStart=, which systemd refuses,
    # so the applet never starts. Disable the override and start blueman-applet from
    # the Hyprland autostart instead.
    withApplet = false;
  };
}
