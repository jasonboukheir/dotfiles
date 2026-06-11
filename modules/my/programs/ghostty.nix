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

  themedSettings = theme: let
    c = theme.colors;
  in
    {
      background = "#${c.base00}";
      foreground = "#${c.base05}";
      cursor-color = "#${c.base05}";
      cursor-text = "#${c.base00}";
      selection-background = "#${c.base02}";
      selection-foreground = "#${c.base05}";
      palette = lib.imap0 (i: hex: "${toString i}=#${hex}") (ansiPalette c);
    }
    // lib.optionalAttrs (theme.fonts ? monospace) {
      font-family =
        [theme.fonts.monospace.name]
        ++ lib.optional (theme.fonts ? emoji) theme.fonts.emoji.name;
      # macOS sizes fonts against 72 dpi where Linux assumes 96; scale by 4/3
      # so the same stylix size renders equally tall (mirrors HM-stylix).
      font-size =
        (theme.fonts.sizes.terminal or 12)
        * (
          if pkgs.stdenv.isDarwin
          then 4.0 / 3.0
          else 1
        );
    }
    // lib.optionalAttrs (theme.opacity ? terminal) {
      background-opacity = theme.opacity.terminal;
    };
in {
  name = "ghostty";
  # The source ghostty package doesn't build on darwin; ghostty-bin is the
  # upstream-signed Ghostty.app plus a bin/ghostty CLI wrapper.
  defaultPackage =
    if pkgs.stdenv.isDarwin
    then "ghostty-bin"
    else "ghostty";
  themeable = true;

  options = {
    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [bool int float str (listOf str)]);
      default = {};
      example = {
        theme = "GruvboxDark";
        palette = ["0=#1d2021" "1=#cc241d"];
      };
      description = ''
        ghostty config baked into this wrapper and loaded via `--config-file`.
        List values render as repeated `key = item` lines (e.g. `palette`).
        When stylix theming is on, the base16 palette/fonts/opacity populate
        the matching keys below these `settings`, so explicit settings win.
        ghostty loads CLI-passed config files after the default user files, so
        the baked settings also win over `~/.config/ghostty/config` — leave a
        key unset here to keep it user-tunable.
      '';
    };
  };

  # The base16 palette, fonts and terminal opacity mapped into ghostty's keys
  # (what HM-stylix's ghostty target used to emit), plus the cross-host base
  # settings the old shared home-manager module carried.
  settingsDefaults = {
    theme ? null,
    ...
  }:
    {
      window-theme = "auto";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      macos-option-as-alt = true;
    }
    // lib.optionalAttrs (theme != null) (themedSettings theme);

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    configFile = pkgs.writeText "ghostty-config" (renderConfig cfg.settings);
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "ghostty";
      flags = lib.optional (cfg.settings != {}) "--config-file=${configFile}";
      # The wrapper only reaches PATH launches; consumers that must feed the
      # fixed user config paths ghostty reads on its own (the darwin Dock
      # seeding, fedora's GNOME-activated launches) link this same file.
      passthru = {inherit configFile;};
    };
}
