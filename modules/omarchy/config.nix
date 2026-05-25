{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    enable = lib.mkEnableOption "Omarchy-esque Hyprland config";
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
        default = "zeditor";
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
}
