{lib, ...}: {
  options.thebeast.greeterDefaultSession = lib.mkOption {
    type = lib.types.str;
    default = "hyprland";
    description = ''
      Session preselected in the greeter dropdown when it actually
      shows (gamer is autoLogin'd via jovian, so the greeter only
      surfaces after a session exits). SDDM has no native per-user
      default; this is a single global preselect.
    '';
  };

  options.gaming = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "gamer";
      description = "Username for the gaming account";
    };

    defaultDesktopSession = lib.mkOption {
      type = lib.types.str;
      default = "hyprland";
      description = ''
        Desktop session jovian.steam hands to "Switch to Desktop".
        Must match a session name under services.displayManager.sessionData.sessionNames
        (jovian appends `.desktop` when writing the SDDM override).
      '';
    };

    exitToGreeter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Land on the display manager's greeter whenever a session exits,
        instead of jovian's default of re-autologin'ing gamer into
        gamescope. Forces SDDM's Autologin.Relogin off, which also
        suppresses steamos-manager's one-shot Switch-to-Desktop
        temp-login (proved in tests/steamos-autologin.nix) — so Steam's
        "Switch to Desktop" / exit lands on the greeter too. That is the
        intended flow on thebeast: exiting Steam should offer the
        session picker (preselecting thebeast.greeterDefaultSession) so
        jasonbk can get straight into the Hyprland dev session.
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
