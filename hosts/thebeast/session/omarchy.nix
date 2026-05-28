{...}: {
  # jasonbk's omarchy/Hyprland session. Part of the desktop-session
  # surface SDDM/plasma-login-manager hands off to.
  omarchy.enable = true;
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 1;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdr";
    sdrBrightness = 1.0;
    sdrSaturation = 1.15;
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 250;
    minLuminance = 0.005;
    maxLuminance = 1000;
    maxAvgLuminance = 500;
  };
  omarchy.pim = "gnome";
  omarchy.waybar.hasBattery = false;
}
