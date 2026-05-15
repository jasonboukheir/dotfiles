{
  config,
  lib,
  ...
}: let
  cfg = config.gaming;
in
  lib.mkIf config.gaming.enable {
    gaming.user = "gamer";

    jovian.steam.enable = true;
    jovian.steam.autoStart = true;
    jovian.steam.user = cfg.user;
    jovian.steam.desktopSession = "plasma";
    jovian.steamos.useSteamOSConfig = false;
    jovian.devices.steamdeck.enable = false;
    jovian.hardware.has.amd.gpu = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    services.desktopManager.plasma6.enable = true;

    # EmptyPassword lets the SDDM greeter submit "" to PAM, which the
    # sddm→login stack accepts via `nullok` on pam_unix. Needed so "Switch
    # User" from Plasma can re-select the passwordless gamer account.
    services.displayManager.sddm.settings.General.EmptyPassword = true;

    # /dev/uinput access for Steam Input's virtual mouse/keyboard mapping
    # (the path the 8BitDo controller takes when Steam runs in Plasma).
    hardware.uinput.enable = true;
  }
