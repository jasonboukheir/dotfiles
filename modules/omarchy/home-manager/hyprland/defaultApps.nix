{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    defaultApps = {
      calendar = lib.mkOption {
        default = "morgen";
        type = lib.types.str;
        description = "Command to use when launching calendar";
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
        default = "spotify";
        type = lib.types.str;
        description = "Command to use when launching music";
      };
      passwordManager = lib.mkOption {
        default = "1password";
        type = lib.types.str;
        description = "Command to use when launching password manager";
      };
      messenger = lib.mkOption {
        default = "signal-desktop";
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
  config = {
    wayland.windowManager.hyprland.settings = {
      "$calendar" = cfg.defaultApps.calendar;
      "$terminal" = cfg.defaultApps.terminal;
      "$editor" = cfg.defaultApps.editor;
      "$fileManager" = cfg.defaultApps.fileManager;
      "$browser" = cfg.defaultApps.browser;
      "$music" = cfg.defaultApps.music;
      "$passwordManager" = cfg.defaultApps.passwordManager;
      "$messenger" = cfg.defaultApps.messenger;
      "$webapp" = cfg.defaultApps.webapp;
      monitor = [];
    };
  };
}
