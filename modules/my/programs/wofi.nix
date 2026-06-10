{
  lib,
  pkgs,
}: let
  renderConfig = settings:
    lib.generators.toKeyValue {} (lib.filterAttrs (_name: value: value != null) settings);

  # Mirrors stylix's wofi home-manager target (modules/wofi/hm.nix at the
  # pinned rev) so dropping HM-stylix keeps the launcher's appearance.
  themedStyle = theme: let
    c = theme.colors;
    fontFamily = theme.fonts.monospace.name or "monospace";
    fontSize = toString (theme.fonts.sizes.popups or 10);
  in ''
    window {
      font-family: "${fontFamily}";
      font-size: ${fontSize}pt;
      background-color: #${c.base00};
      color: #${c.base05};
    }

    #entry:nth-child(odd) {
      background-color: #${c.base00};
    }

    #entry:nth-child(even) {
      background-color: #${c.base01};
    }

    #entry:selected {
      background-color: #${c.base02};
    }

    #input {
      background-color: #${c.base01};
      color: #${c.base04};
      border-color: #${c.base02};
    }

    #input:focus {
      border-color: #${c.base0A};
    }
  '';
in {
  name = "wofi";
  defaultPackage = "wofi";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = with lib.types; attrsOf (nullOr (oneOf [bool int float str]));
      default = {};
      example = {
        width = 600;
        show = "drun";
        allow_markup = true;
      };
      description = ''
        wofi config baked into the wrapper and loaded via `--conf`, rendered as
        the key=value format of {manpage}`wofi(5)` (null values are omitted).
        `--conf` replaces wofi's default config path, so the user's
        `~/.config/wofi/config` is not read once any settings are baked;
        command-line flags still override.
      '';
    };

    style = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        window {
          border-radius: 8px;
        }
      '';
      description = ''
        CSS stylesheet baked into the wrapper and loaded via `--style`, see
        {manpage}`wofi(7)`. When stylix theming is on, base16
        window/entry/input rules are prepended, so these lines win on
        conflicts.
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    theme ? null,
    ...
  }: let
    confFile = pkgs.writeText "wofi-config" (renderConfig cfg.settings);
    styleText = lib.optionalString (theme != null) (themedStyle theme) + cfg.style;
    styleFile = pkgs.writeText "wofi-style.css" styleText;
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "wofi";
      flags =
        lib.optionals (cfg.settings != {}) ["--conf" "${confFile}"]
        ++ lib.optionals (styleText != "") ["--style" "${styleFile}"];
    };
}
