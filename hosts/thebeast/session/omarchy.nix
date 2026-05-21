{...}: {
  # jasonbk's omarchy/Hyprland session. Part of the desktop-session
  # surface SDDM/plasma-login-manager hands off to.
  omarchy.enable = true;
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 2;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdr";
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 203;
  };
  omarchy.pim = "gnome";
  omarchy.waybar.hasBattery = false;
}
