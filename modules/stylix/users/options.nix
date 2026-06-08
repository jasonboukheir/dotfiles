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
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
