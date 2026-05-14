{...}: {
  omarchy.enable = true;
  omarchy.homeManagerUsers = ["jasonbk"];
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 1;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdr";
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 203;
  };
  omarchy.pim = "gnome";
  omarchy.waybar.hasBattery = false;
  omarchy.macKeybindings = {
    enable = true;
  };
}
