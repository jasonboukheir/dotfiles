{
  config,
  lib,
  pkgs,
  ...
}: {
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = "jasonbk";
    desktopSession = "hyprland";
  };
  jovian.devices.steamdeck = {
    enable = false;
    enablePerfControlUdevRules = false;
  };
  jovian.hardware.has.amd.gpu = false;
  services.greetd.settings.default_session.command = lib.mkForce "${pkgs.jovian-greeter}/bin/jovian-greeter ${config.jovian.steam.user}";
  environment.systemPackages = with pkgs; [
    gamescope
    mangohud
  ];
}
