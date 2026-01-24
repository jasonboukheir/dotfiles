{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
in {
  options.omarchy = {
    enable = lib.mkEnableOption "Omarchy-esque Hyprland config";
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
