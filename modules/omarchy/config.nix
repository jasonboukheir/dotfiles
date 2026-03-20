{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    enable = lib.mkEnableOption "Omarchy-esque Hyprland config";
    hdr = {
      enable = lib.mkEnableOption "HDR and 10-bit color support";
      sdrBrightness = lib.mkOption {
        type = lib.types.addCheck lib.types.float (x: x >= 0.5 && x <= 2.5);
        default = 1.0;
        description = "Default SDR brightness when HDR is active (0.5–2.5)";
      };
    };
    macKeybindings = {
      enable = lib.mkEnableOption "macOS-style keybindings via keyd";
      capsLockAsCmd = lib.mkEnableOption "remap Caps Lock to act as Cmd (Meta)";
      terminalApps = lib.mkOption {
        default = ["ghostty"];
        type = lib.types.listOf lib.types.str;
        description = "WM_CLASS names of terminal apps that need Ctrl+Shift for copy/paste instead of Ctrl";
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
        default = "brave --new-window --ozone-platform=wayland";
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
