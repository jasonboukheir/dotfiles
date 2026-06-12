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
  # Known displays get desc:-keyed rules derived from thebeast.displays
  # (session/displays.nix) so the whole chain commits identical streams
  # — a mismatch here forced a DSC link retrain (seconds of black and
  # the monitor's loading spinner) on every Steam↔desktop handoff. The
  # fallback rule covers unknown displays: "highrr" is the same
  # highest-refresh-at-native policy the kwin greeter and gamescope
  # default to, and SDR because an unknown panel's HDR support is
  # unknown (the greeter is also SDR on unknown displays).
  omarchy.monitor = {
    mode = "highrr";
    vrr = 1;
    hdr = false;
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
