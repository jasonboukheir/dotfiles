{
  config,
  lib,
  systemConfig,
  ...
}: let
  cfg = config.omarchy;
  systemCfg = systemConfig.omarchy;
in {
  options.omarchy = {
    defaultApps = {
      calendar = lib.mkOption {
        default = systemCfg.defaultApps.calendar;
        type = lib.types.str;
        description = "Command to use when launching calendar";
      };
      reminders = lib.mkOption {
        default = systemCfg.defaultApps.reminders;
        type = lib.types.str;
        description = "Command to use when launching reminders";
      };
      terminal = lib.mkOption {
        default = systemCfg.defaultApps.terminal;
        type = lib.types.str;
        description = "Command to use when launching terminal";
      };
      editor = lib.mkOption {
        default = systemCfg.defaultApps.editor;
        type = lib.types.str;
        description = "Command to use when launching code editor";
      };
      fileManager = lib.mkOption {
        default = systemCfg.defaultApps.fileManager;
        type = lib.types.str;
        description = "Command to use when launching fileManager";
      };
      browser = lib.mkOption {
        default = systemCfg.defaultApps.browser;
        type = lib.types.str;
        description = "Command to use when launching browser";
      };
      music = lib.mkOption {
        default = systemCfg.defaultApps.music;
        type = lib.types.str;
        description = "Command to use when launching music";
      };
      passwordManager = lib.mkOption {
        default = systemCfg.defaultApps.passwordManager;
        type = lib.types.str;
        description = "Command to use when launching password manager";
      };
      messenger = lib.mkOption {
        default = systemCfg.defaultApps.messenger;
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
      "$reminders" = cfg.defaultApps.reminders;
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
