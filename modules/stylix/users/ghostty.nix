{lib, ...}: let
  # base16 → 16-colour ANSI terminal slots, the standard base16 mapping
  # (bright variants reuse the normal accent hues).
  ansiPalette = c: [
    c.base00 # 0  black
    c.base08 # 1  red
    c.base0B # 2  green
    c.base0A # 3  yellow
    c.base0D # 4  blue
    c.base0E # 5  magenta
    c.base0C # 6  cyan
    c.base05 # 7  white
    c.base03 # 8  bright black
    c.base08 # 9  bright red
    c.base0B # 10 bright green
    c.base0A # 11 bright yellow
    c.base0D # 12 bright blue
    c.base0E # 13 bright magenta
    c.base0C # 14 bright cyan
    c.base07 # 15 bright white
  ];

  perUser = {config, ...}: let
    stylix = config.stylix;
    c = stylix.colors;

    # TODO: only the base16 palette is mapped; wire `stylix.fonts` into
    # ghostty's font-family/font-size and `stylix.opacity.terminal` into
    # background-opacity to match HM-stylix's ghostty target.
    # https://github.com/jasonboukheir/dotfiles/issues/44
    themed = {
      background = "#${c.base00}";
      foreground = "#${c.base05}";
      cursor-color = "#${c.base05}";
      cursor-text = "#${c.base00}";
      selection-background = "#${c.base02}";
      selection-foreground = "#${c.base05}";
      palette = lib.imap0 (i: hex: "${toString i}=#${hex}") (ansiPalette c);
    };
  in {
    options.stylix.targets.ghostty.enable =
      lib.mkEnableOption "stylix theming for this user's ghostty wrapper"
      // {
        default = stylix.enable;
        defaultText = lib.literalExpression "config.stylix.enable";
      };

    config = lib.mkIf (config.stylix.targets.ghostty.enable && config.programs.ghostty.enable) {
      programs.ghostty.settings = lib.mapAttrs (_: lib.mkDefault) themed;
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
