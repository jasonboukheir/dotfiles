{pkgs, ...}: {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "jasonbk";
    desktopSession = "plasma";
  };
  jovian.devices.steamdeck = {
    enable = false;
    enablePerfControlUdevRules = false;
  };
  jovian.hardware.has.amd.gpu = false;
  environment.systemPackages = with pkgs; [
    gamescope
    mangohud
  ];
}
