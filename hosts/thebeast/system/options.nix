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

  options.thebeast.displays = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        make = lib.mkOption {
          type = lib.types.str;
          description = ''
            Panel manufacturer string as the compositors report it
            (`hyprctl monitors` "make"). "<make> <model>" is gamescope's
            key in its mode-save file, and with the serial appended it
            is Hyprland's `desc:` matcher.
          '';
        };
        model = lib.mkOption {type = lib.types.str;};
        serial = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Panel serial as compositors report it; part of Hyprland's desc: matcher only.";
        };
        connector = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            DRM connector to pin via the kernel video= parameter
            (fbcon). The one consumer that cannot match by
            EDID: a *different* panel plugged into this connector gets
            the mode forced on it too. null skips the kernel pin.
          '';
        };
        width = lib.mkOption {type = lib.types.int;};
        height = lib.mkOption {type = lib.types.int;};
        refreshHz = lib.mkOption {
          type = lib.types.int;
          description = "Refresh in whole Hz, for the WxH@Hz strings (kernel video=, Hyprland mode, gamescope mode-save).";
        };
        refreshMillihertz = lib.mkOption {
          type = lib.types.int;
          description = ''
            Refresh in mHz for the greeter kwin's output config,
            computed with kwin's exact formula
            (DrmConnector::refreshRateForMode, after Weston):
            (clock_khz * 1000000 / htotal + vtotal / 2) / vtotal in
            integer math, from the mode's detailed timing. Must match
            exactly — kwin falls back to its own choice (highest
            refresh) on any mismatch.
          '';
        };
        edidIdentifier = lib.mkOption {
          type = lib.types.str;
          description = ''
            kwin's EDID identity string: "<pnp-id> <product-code>
            <serial-number> <week> <year> <model-year>" (decimal, 0
            for unset fields — see Edid::Edid in kwin).
          '';
        };
        edidHash = lib.mkOption {
          type = lib.types.str;
          description = "md5 hex digest of the raw EDID blob (md5sum /sys/class/drm/<connector>/edid).";
        };
        hdr = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Drive this display in HDR (BT.2020 + PQ) in every
            compositor that touches it. Mixed signaling is as bad as a
            mode mismatch: amdgpu treats a colorspace change as a full
            modeset (= DP link retrain) even at identical timings.
          '';
        };
        sdrPaperWhiteNits = lib.mkOption {
          type = lib.types.int;
          default = 200;
          description = ''
            Luminance of SDR white while the display runs HDR, in nits
            (kwin's sdrBrightness / referenceLuminance). Keep equal to
            omarchy.hdr.sdrMaxLuminance (Hyprland's sdr_max_luminance)
            so SDR content doesn't visibly shift brightness across the
            greeter -> Hyprland handoff.
          '';
        };
        vrr = lib.mkOption {
          type = lib.types.enum [0 1 2 3];
          default = 0;
          description = "Hyprland vrr policy for this display's rule.";
        };
      };
    });
    default = [
      {
        # Odyssey G95SC on the RX 9070 XT. Identity from the live EDID
        # (SAM, product 57384, serial 0, week 3 of 2023); timing from
        # the DisplayID 120Hz DTD: clock 972750kHz, htotal 5320,
        # vtotal 1524 → 119979mHz. 5120x1440@240 needs DSC at a
        # ~1.94GHz dotclock, and any 120↔240 switch is a full link
        # retrain this monitor spends multiple seconds on — every
        # consumer pins 120 so handoffs stay zero-delta.
        make = "Samsung Electric Company";
        model = "Odyssey G95SC";
        serial = "H1AK500000";
        connector = "DP-2";
        width = 5120;
        height = 1440;
        refreshHz = 120;
        refreshMillihertz = 119979;
        edidIdentifier = "SAM 57384 0 3 2023 0";
        edidHash = "f09623174868137861820779fe6809f5";
        # omarchy.hdr runs the desktop in BT.2020/PQ and jovian-steam.nix
        # forces gamescope to match; the greeter joins via this flag.
        hdr = true;
        sdrPaperWhiteNits = 300;
        vrr = 1;
      }
    ];
    description = ''
      Per-display profiles every mode-setter in the boot/session chain
      derives from, so a known display sees identical timings, bit
      depth, and colorspace from fbcon through gamescope, the SDDM
      greeter, and Hyprland. When consecutive DRM masters commit the
      same stream, amdgpu skips DisplayPort link training entirely
      ("Mode change not required" fast path) and session handoffs stop
      black-screening; any delta — mode, refresh, or colorspace —
      costs a full retrain.

      Consumers (see session/displays.nix and boot.nix):
      - kernel video= for fbcon (connector-keyed; the only
        non-EDID-aware pin)
      - the greeter kwin's kwinoutputconfig.json (EDID-keyed; without
        it kwin picks the highest refresh at native resolution)
      - Hyprland desc:-keyed monitor rules via omarchy.extraMonitors
      - gamescope's mode-save file, keyed "<make> <model>" (its
        embedded DRM backend otherwise defaults to highest refresh)

      Displays not listed here get each compositor's default, which is
      highest-refresh-at-native for kwin and gamescope; Hyprland is
      aligned to that via the omarchy fallback rule (mode "highrr") so
      even unknown displays see consistent timings between sessions.
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

    shaderCacheMaxSize = lib.mkOption {
      type = lib.types.str;
      default = "32G";
      description = ''
        MESA_SHADER_CACHE_MAX_SIZE for the Steam/gamescope session. Mesa's
        on-disk RADV cache defaults to a hardcoded 1G *per architecture*,
        so a library of large Proton titles evicts older games' compiled
        pipelines and recompiles them on every launch. Raising the cap to
        comfortably exceed the working set keeps caches warm across
        launches. Accepts a bare number (GiB) or a K/M/G suffix.
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
