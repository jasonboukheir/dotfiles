{
  lib,
  pkgs,
}: let
  renderValue = v:
    if lib.isBool v
    then lib.boolToString v
    else toString v;

  renderEntry = key: value:
    if lib.isList value
    then map (item: "${key} = ${renderValue item}") value
    else ["${key} = ${renderValue value}"];

  renderConfig = settings:
    lib.concatStringsSep "\n" (lib.concatLists (lib.mapAttrsToList renderEntry settings)) + "\n";

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

  # TODO: only the base16 palette is mapped; wire `theme.fonts` into ghostty's
  # font-family/font-size and `theme.opacity.terminal` into background-opacity to
  # match HM-stylix's ghostty target.
  # https://github.com/jasonboukheir/dotfiles/issues/44
  themedSettings = theme: let
    c = theme.colors;
  in {
    background = "#${c.base00}";
    foreground = "#${c.base05}";
    cursor-color = "#${c.base05}";
    cursor-text = "#${c.base00}";
    selection-background = "#${c.base02}";
    selection-foreground = "#${c.base05}";
    palette = lib.imap0 (i: hex: "${toString i}=#${hex}") (ansiPalette c);
  };
in {
  name = "ghostty";
  defaultPackage = "ghostty";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [bool int str (listOf str)]);
      default = {};
      example = {
        theme = "GruvboxDark";
        palette = ["0=#1d2021" "1=#cc241d"];
      };
      description = ''
        ghostty config baked into this wrapper and loaded via `--config-file`.
        List values render as repeated `key = item` lines (e.g. `palette`). When
        stylix theming is on, the base16 palette populates the color keys; these
        `settings` still win on conflicts, as does the user's own
        `~/.config/ghostty/config`.
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
    finalSettings =
      if theme == null
      then cfg.settings
      else lib.recursiveUpdate (themedSettings theme) cfg.settings;

    configFile = pkgs.writeText "ghostty-config" (renderConfig finalSettings);
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "ghostty";
      flags = lib.optional (finalSettings != {}) "--config-file=${configFile}";
    };
}
