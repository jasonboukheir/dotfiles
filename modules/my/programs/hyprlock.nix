{
  lib,
  pkgs,
}: let
  inherit (import ../lib/hyprland {inherit lib;}) toHyprlang settingsType;

  # The same slots stylix's hyprlock target paints (modules/hyprlock/hm.nix at
  # the pinned stylix rev). Its background.path wallpaper is not replicated:
  # the my.* theme payload carries no image.
  # TODO: wire stylix.image into the theme payload so the lock screen gets the
  # wallpaper back. https://github.com/jasonboukheir/dotfiles/issues/48
  themedSettings = theme: let
    c = theme.colors;
  in {
    background.color = "rgb(${c.base00})";
    input-field = {
      outer_color = "rgb(${c.base03})";
      inner_color = "rgb(${c.base00})";
      font_color = "rgb(${c.base05})";
      fail_color = "rgb(${c.base08})";
      check_color = "rgb(${c.base0A})";
    };
  };
in {
  name = "hyprlock";
  defaultPackage = "hyprlock";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = settingsType;
      default = {};
      example = {
        general.hide_cursor = true;
        input-field = [
          {
            monitor = "";
            placeholder_text = "Password…";
          }
        ];
      };
      description = ''
        hyprlock config baked into this wrapper and loaded via `--config`.
        When stylix theming is on, the base16 palette populates the
        background/input-field color keys (attrset form, so list-form
        `background`/`input-field` settings conflict with theming); these
        `settings` win on conflicts.

        hyprlock itself has no daemon: hypridle's `lock_cmd` and
        `loginctl lock-session` invoke this wrapped binary. PAM still has to
        allow it — see `security.pam.services.hyprlock` at the NixOS layer.
      '';
    };
  };

  settingsDefaults = {theme ? null, ...}:
    lib.optionalAttrs (theme != null) (themedSettings theme);

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    configFile = pkgs.writeText "hyprlock.conf" (toHyprlang cfg.settings);
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "hyprlock";
      flags = lib.optionals (cfg.settings != {} && cfg.settings != null) ["--config" "${configFile}"];
    };
}
