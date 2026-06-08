{
  config,
  lib,
  ...
}: let
  systemStylix =
    if config ? stylix
    then config.stylix
    else {};

  systemColors =
    if (config ? lib && config.lib ? stylix && config.lib.stylix ? colors)
    then lib.filterAttrs (_: lib.isString) config.lib.stylix.colors
    else {};

  # `stylix.cursor` is a NixOS/HM-stylix option; the darwin stylix module
  # never declares it (macOS has no X cursor themes). Guard on its presence
  # so the per-user cursor inherits the themed system cursor on Linux and
  # falls back to null on darwin instead of throwing.
  systemCursor =
    if (config ? stylix && config.stylix ? cursor)
    then config.stylix.cursor
    else {};

  perUser = _: {
    options.stylix = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = systemStylix.enable or false;
        defaultText = lib.literalExpression "config.stylix.enable";
        description = ''
          Whether to theme this user's wrappers from stylix. Defaults to the
          system stylix setting; the per-app targets under
          `modules/stylix/users` key off this.
        '';
      };

      polarity = lib.mkOption {
        type = lib.types.enum ["either" "light" "dark"];
        default = systemStylix.polarity or "dark";
        defaultText = lib.literalExpression "config.stylix.polarity";
        description = "Theme polarity for this user. Defaults to the system stylix polarity.";
      };

      colors = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = systemColors;
        defaultText = lib.literalExpression "config.lib.stylix.colors";
        example = lib.literalExpression ''{base00 = "1d2021"; base05 = "ebdbb2";}'';
        description = ''
          base16 palette (`base00`..`base0F`, hex without a leading `#`) used to
          theme this user's wrappers. Defaults to the resolved system stylix
          palette; override to give this user a different scheme.
        '';
      };

      fonts = lib.mkOption {
        type = lib.types.attrs;
        default = systemStylix.fonts or {};
        defaultText = lib.literalExpression "config.stylix.fonts";
        description = "Fonts for this user's wrappers. Defaults to the system stylix fonts.";
      };

      opacity = lib.mkOption {
        type = lib.types.attrs;
        default = systemStylix.opacity or {};
        defaultText = lib.literalExpression "config.stylix.opacity";
        description = "Opacity settings for this user's wrappers. Defaults to the system stylix opacity.";
      };

      cursor = {
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = systemCursor.name or null;
          defaultText = lib.literalExpression "config.stylix.cursor.name or null";
          description = ''
            Cursor theme name. Inherits the themed system stylix cursor on
            NixOS; null where the system stylix has no cursor (darwin), which
            leaves cursor-consuming targets inactive.
          '';
        };

        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = systemCursor.package or null;
          defaultText = lib.literalExpression "config.stylix.cursor.package or null";
          description = "Cursor theme package a target installs into this user's icon path. Inherits the system stylix cursor when defined.";
        };

        size = lib.mkOption {
          type = lib.types.int;
          default = systemCursor.size or 24;
          defaultText = lib.literalExpression "config.stylix.cursor.size or 24";
          description = "Cursor size (XCURSOR_SIZE/HYPRCURSOR_SIZE). Inherits the system stylix cursor size when defined.";
        };
      };
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
