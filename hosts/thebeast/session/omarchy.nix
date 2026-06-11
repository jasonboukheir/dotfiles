{config, ...}: {
  # jasonbk's omarchy/Hyprland session. Part of the desktop-session
  # surface SDDM hands off to.
  omarchy.enable = true;

  # The uwsm-managed session entry is the one the greeter should land
  # on; follows omarchy.uwsm.enable so the fallback stays one flag.
  thebeast.greeterDefaultSession =
    if config.omarchy.uwsm.enable
    then "hyprland-uwsm"
    else "hyprland";

  # gamer no longer runs Plasma — Steam's "Switch to Desktop" hands off to
  # the same Hyprland entry the greeter preselects (jovian-setup-desktop-session
  # records it with steamos-manager, so it must name a session that exists).
  gaming.defaultDesktopSession = config.thebeast.greeterDefaultSession;
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 1;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdr";
    sdrBrightness = 1.0;
    sdrSaturation = 1.0;
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 300;
    minLuminance = 0.005;
    maxLuminance = 1000;
    maxAvgLuminance = 500;
  };
  omarchy.pim = "gnome";
  omarchy.waybar.hasBattery = false;
}
