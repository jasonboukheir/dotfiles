{...}: {
  omarchy.enable = true;
  omarchy.monitor = {
    mode = "5120x1440@120";
    vrr = 1;
  };
  omarchy.hdr = {
    enable = true;
    colorManagement = "hdredid";
    sdrMinLuminance = 0.005;
    sdrMaxLuminance = 203;
  };
  omarchy.pim = "gnome";
  omarchy.macKeybindings = {
    enable = true;
  };
}
