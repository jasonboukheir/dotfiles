{
  lib,
  pkgs,
}: let
  inherit (import ../lib/hyprland {inherit lib;}) toHyprlang settingsType;
in {
  name = "hyprpaper";
  defaultPackage = "hyprpaper";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = settingsType;
      default = {};
      example = {
        wallpaper = [
          {
            monitor = "";
            path = "/path/to/wallpaper.png";
          }
        ];
        splash = false;
      };
      description = ''
        hyprpaper config baked into this wrapper and loaded via `--config`.
        When stylix theming is on and the theme carries a wallpaper, it is
        applied to all monitors with the splash disabled (what stylix's HM
        hyprpaper target wrote); these `settings` win on conflicts.
      '';
    };
  };

  settingsDefaults = {theme ? null, ...}:
    lib.optionalAttrs (theme != null && (theme.image or null) != null) {
      wallpaper = [
        {
          monitor = "";
          path = theme.image;
        }
      ];
      splash = false;
    };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    configFile = pkgs.writeText "hyprpaper.conf" (toHyprlang cfg.settings);
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "hyprpaper";
      flags = lib.optionals (cfg.settings != {} && cfg.settings != null) ["--config" "${configFile}"];
    };
}
