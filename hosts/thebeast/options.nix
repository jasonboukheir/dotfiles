{lib, ...}: {
  options.gaming = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable gaming mode with Steam, emulators, and gaming packages";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "gamer";
      description = "Username for the gaming account";
    };

    defaultDesktopSession = lib.mkOption {
      type = lib.types.str;
      default = "plasma.desktop";
      description = ''
        Desktop session steamos-manager hands to "Switch to Desktop" by default.
        Must match a .desktop file under services.displayManager.sessionData.desktops.
      '';
    };

    romDir = lib.mkOption {
      type = lib.types.str;
      default = "/games/roms";
      description = "Base directory for ROM storage";
    };

    systems = lib.mkOption {
      type = with lib.types; listOf attrs;
      default = [];
      description = "Emulation system definitions driving RetroArch cores, ROM dirs, and SRM parsers";
    };
  };
}
