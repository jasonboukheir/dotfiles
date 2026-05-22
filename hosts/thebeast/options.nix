{lib, ...}: {
  options.thebeast.displayManager = lib.mkOption {
    type = lib.types.enum ["sddm" "plasma-login-manager"];
    default = "sddm";
    description = ''
      Display manager to use. `plasma-login-manager` (KDE's new
      SDDM-replacement, landed in Plasma 6.6 / nixos-unstable Jan 2026)
      is experimental — KDE upstream warns "works for me" status, no
      virtual-keyboard polish yet. Both honour the standard
      services.displayManager.autoLogin contract, so the jovian
      autoStart path stays intact across either choice.
    '';
  };

  options.thebeast.greeterDefaultSession = lib.mkOption {
    type = lib.types.str;
    default = "hyprland";
    description = ''
      Session preselected in the greeter dropdown when it actually
      shows (gamer is autoLogin'd via jovian, so the greeter only
      surfaces after jasonbk logs out / Switch-User from plasma).
      SDDM and plasma-login-manager both lack native per-user defaults;
      this is a single global preselect.
    '';
  };

  options.thebeast.sessionsByUser = lib.mkOption {
    type = with lib.types; attrsOf (listOf str);
    default = {};
    example = lib.literalExpression ''
      {
        jasonbk = [ "hyprland" ];
        gamer = [ "plasma" "gamescope-wayland" ];
      }
    '';
    description = ''
      Per-user allowlist of session basenames (no `.desktop` suffix)
      surfaced in the SDDM greeter dropdown. Drives theme.conf for
      the thebeast SDDM theme, which filters sessionModel at display
      time. The underlying session files in wayland-sessions/ stay
      intact, so `steamosctl set-default-desktop-session`,
      `autoLogin.Session`, and jovian's gamescope handoff are
      unaffected. Users not listed here see every installed session
      (safe default for new accounts before this attrset is updated).
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
      default = "plasma";
      description = ''
        Desktop session jovian.steam hands to "Switch to Desktop".
        Must match a session name under services.displayManager.sessionData.sessionNames
        (jovian appends `.desktop` when writing the SDDM override).
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
