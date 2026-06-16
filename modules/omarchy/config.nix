{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    enable = lib.mkEnableOption "Omarchy-esque Hyprland config";
    uwsm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the Hyprland session under UWSM (issues #40/#48). This is the
        single fallback flag: it flips `programs.hyprland.withUWSM`, the
        uwsm compositor registration + greeter session entry, the
        `sessionTarget` default, and the generated hyprland config's
        session-start hook (`uwsm finalize` vs the recreated
        dbus-update + hyprland-session.target recycle, see
        modules/omarchy/hyprland/autostart.nix) together, so turning it
        off restores the pre-UWSM hyprland-session.target world in one
        move.
      '';
    };
    uwsm.oomPolicy = lib.mkOption {
      type = lib.types.enum ["continue" "stop" "kill"];
      default = "continue";
      description = ''
        OOMPolicy for uwsm's `wayland-wm@.service`, delivered as a
        systemd drop-in (the unit itself is shipped by the uwsm package,
        so a drop-in is the only way to amend it without shadowing it).

        systemd's default `stop` turns any kernel OOM kill inside the
        compositor's cgroup into a stop of the whole unit — a full
        session teardown back to the greeter. Anything launched by a raw
        `exec` bind (and every child of those terminals, e.g. a fat nix
        eval) lives in that cgroup, so a single OOM-killed process logs
        the user out. `continue` confines the damage to the process the
        kernel actually killed.
      '';
    };
    sessionTarget = lib.mkOption {
      type = lib.types.str;
      defaultText = lib.literalExpression ''
        if config.omarchy.uwsm.enable
        then "wayland-session@hyprland.desktop.target"
        else "hyprland-session.target"
      '';
      description = ''
        systemd user target that gates every desktop-session service in the
        omarchy stack (waybar, mako, hypridle, …).

        Under UWSM this is `wayland-session@hyprland.desktop.target` — the
        instance is uwsm's compositor ID, the basename of what the shipped
        hyprland-uwsm.desktop entry starts (`uwsm start … hyprland.desktop`).
        It is deliberately not `graphical-session.target` as issue #40
        originally planned: jovian binds its steam units to
        graphical-session.target inside the gamescope session, so anything
        gated there would leak into game mode. The uwsm per-compositor
        target only exists in the Hyprland session, and its
        `wayland-wm@.service` dependency is
        Type=notify — `uwsm finalize` exports WAYLAND_DISPLAY into the
        activation environment before notifying — so services ordered
        After it still see the socket on their first attempt (issue #32).

        Without UWSM, hyprland-session.target serves the same role: the
        generated hyprland config starts it (from its `hyprland.start`
        hook, see modules/omarchy/hyprland/autostart.nix) only after the
        wayland socket is published and
        `dbus-update-activation-environment --systemd` has run.
      '';
    };
    monitor = {
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Monitor resolution and refresh rate (e.g. 5120x1440@120)";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Monitor position in layout";
      };
      scale = lib.mkOption {
        type = lib.types.either lib.types.int lib.types.float;
        default = 1;
        description = "Monitor scale factor";
      };
      vrr = lib.mkOption {
        type = lib.types.enum [0 1 2 3];
        default = 0;
        description = "Variable refresh rate (0=off, 1=on, 2=fullscreen only, 3=fullscreen+game heuristic)";
      };
      hdr = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Apply the omarchy.hdr settings to the fallback monitor rule.
          Disable when only specific displays (extraMonitors entries
          with hdr = true) should be driven in HDR, so an unknown SDR
          panel isn't handed BT2020 primaries.
        '';
      };
    };
    headlessFallback = {
      enable =
        lib.mkEnableOption ''
          a persistent headless output, created at session start, that keeps
          the monitor count >= 1 so unplugging the last/only physical display
          (e.g. swapping a DisplayPort cable) doesn't crash Hyprland. On
          disconnect Hyprland migrates the workspaces to this dummy output; on
          reconnect they move back to the real display.

          A pure-Hyprland-<0.56 workaround: the internal HEADLESS-1 fallback is
          broken in 0.55 and fixed upstream for 0.56 (hyprwm/Hyprland 0aa7a84,
          https://github.com/hyprwm/Hyprland/pull/14547). A build-time warning
          fires once pkgs.hyprland reaches 0.56 to drop it.
        '';
      name = lib.mkOption {
        type = lib.types.str;
        default = "HEADLESS-2";
        description = ''
          Output name the headless rule matches. Hyprland reserves HEADLESS-1
          for its own fallback, and `hyprctl output create headless` (0.55
          takes no name argument) hands out the next free HEADLESS-N, so the
          single output created at session start is deterministically
          HEADLESS-2.
        '';
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "1920x1080@60";
        description = "Mode for the headless fallback output.";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Layout position of the headless fallback output.";
      };
    };
    extraMonitors = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          output = lib.mkOption {
            type = lib.types.str;
            description = "Hyprland output matcher: a connector name or `desc:<make> <model> <serial>`.";
          };
          mode = lib.mkOption {type = lib.types.str;};
          position = lib.mkOption {
            type = lib.types.str;
            default = "auto";
          };
          scale = lib.mkOption {
            type = lib.types.either lib.types.int lib.types.float;
            default = 1;
          };
          vrr = lib.mkOption {
            type = lib.types.enum [0 1 2 3];
            default = 0;
          };
          hdr = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Apply the omarchy.hdr settings to this rule (requires omarchy.hdr.enable).";
          };
        };
      });
      default = [];
      description = ''
        Display-specific monitor rules emitted after the fallback
        omarchy.monitor rule. Hyprland resolves named/desc: matches
        before the empty-output fallback, so these win on the displays
        they describe.
      '';
    };
    hdr = {
      enable = lib.mkEnableOption "HDR and 10-bit color support";
      colorManagement = lib.mkOption {
        type = lib.types.enum ["hdr" "hdredid"];
        default = "hdr";
        description = "Color management preset: hdr uses BT2020 primaries, hdredid uses the monitor's EDID-reported primaries";
      };
      sdrBrightness = lib.mkOption {
        type = lib.types.addCheck lib.types.float (x: x >= 0.5 && x <= 2.5);
        default = 1.0;
        description = "SDR brightness when HDR is active (0.5–2.5)";
      };
      sdrSaturation = lib.mkOption {
        type = lib.types.addCheck lib.types.float (x: x >= 0.0 && x <= 1.5);
        default = 1.0;
        description = "SDR saturation when HDR is active — reduce slightly when brightness > 1.0 to prevent color clipping (0.0–1.5)";
      };
      sdrMinLuminance = lib.mkOption {
        type = lib.types.float;
        default = 0.005;
        description = "SDR minimum luminance for SDR→HDR mapping (0.005 for OLED true black)";
      };
      sdrMaxLuminance = lib.mkOption {
        type = lib.types.int;
        default = 200;
        description = "SDR maximum luminance for SDR→HDR brightness — set to the panel's 100% white window spec (250 for G95SC; 80–400 typical)";
      };
      minLuminance = lib.mkOption {
        type = lib.types.nullOr lib.types.float;
        default = null;
        description = "HDR minimum luminance override (null = use EDID). 0.005 for OLED true black";
      };
      maxLuminance = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "HDR peak luminance override (null = use EDID). Set to the panel's 1–3% white window spec (1000 for G95SC)";
      };
      maxAvgLuminance = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "HDR average luminance override (null = use EDID). Set to the panel's 10% white window spec (500 for G95SC)";
      };
    };
    waybar = {
      hasBattery = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Host has a system battery — when false, the waybar battery module is omitted (avoids crashes on desktops where only peripheral HID++ batteries exist)";
      };
    };
    bluetooth = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.blueman;
        defaultText = lib.literalExpression "pkgs.blueman";
        description = "Bluetooth manager package the waybar bluetooth on-click launches. Defaults to the same blueman the services.blueman module runs, so the indicator and the service stay the same store path.";
      };
    };
    audioControl = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.pavucontrol;
        defaultText = lib.literalExpression "pkgs.pavucontrol";
        description = "GUI audio mixer package the waybar volume on-click launches.";
      };
    };
    defaultApps = {
      calendar = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Command to use when launching calendar";
      };
      contacts = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Command to use when launching contacts";
      };
      reminders = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Command to use when launching reminders";
      };
      terminal = lib.mkOption {
        default = "ghostty";
        type = lib.types.str;
        description = "Command to use when launching terminal";
      };
      editor = lib.mkOption {
        default = "ghostty -e nvim";
        type = lib.types.str;
        description = "Command to use when launching code editor";
      };
      fileManager = lib.mkOption {
        default = "nautilus --new-window";
        type = lib.types.str;
        description = "Command to use when launching fileManager";
      };
      browser = lib.mkOption {
        default = "helium --new-window --ozone-platform=wayland";
        type = lib.types.str;
        description = "Command to use when launching browser";
      };
      music = lib.mkOption {
        default = "supersonic-wayland";
        type = lib.types.str;
        description = "Command to use when launching music";
      };
      passwordManager = lib.mkOption {
        default = "1password";
        type = lib.types.str;
        description = "Command to use when launching password manager";
      };
      messenger = lib.mkOption {
        default = "beeper";
        type = lib.types.str;
        description = "Command to use when launching messenger";
      };
      webapp = lib.mkOption {
        default = "${cfg.defaultApps.browser} --app";
        type = lib.types.str;
        description = "Command to use when launching webapps";
      };
    };
  };

  config.omarchy.sessionTarget = lib.mkDefault (
    if cfg.uwsm.enable
    then "wayland-session@hyprland.desktop.target"
    else "hyprland-session.target"
  );
}
