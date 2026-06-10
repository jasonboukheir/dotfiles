{
  lib,
  pkgs,
}: let
  jsonFormat = pkgs.formats.json {};

  # stylix polarity -> claude-code's two ANSI themes. claude-code reads `theme`
  # from settings.json; dark/light-ansi defer the actual colours to the
  # terminal's own 16-colour palette (which the my.ghostty stylix target owns).
  polarityTheme = polarity:
    if polarity == "light"
    then "light-ansi"
    else "dark-ansi";
in {
  name = "claude-code";
  themeable = true;

  options = {
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.claude-code;
      defaultText = lib.literalExpression "pkgs.claude-code";
      description = ''
        claude-code package to wrap. Defaults to `pkgs.claude-code`, which the
        master overlay (modules/nixpkgs/overlays/claude-code-master.nix) pins to
        nixpkgs-master so a new model is reachable ahead of unstable.

        Set to `null` on hosts where `claude` is preinstalled out-of-band: my.*
        then installs nothing and the preinstalled binary owns its own settings
        via `~/.claude`. `settings`/theming have no effect in that case.
      '';
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      example = {permissions.defaultMode = "acceptEdits";};
      description = ''
        settings.json baked into the wrapper and loaded with claude's
        `--settings` flag, i.e. layered *on top of* the user's writable
        `~/.claude/settings.json` (which still wins). When stylix theming is on,
        `theme` is set from system polarity; these `settings` win on conflicts.
        Ignored when `package = null`.
      '';
    };
  };

  # ~/.claude (runtime state) and ~/.claude/CLAUDE.md (a real mutable dotfile)
  # are deliberately NOT managed here: claude writes into ~/.claude at runtime,
  # so the wrapper only bakes the configured package + settings and leaves that
  # directory writable (the seed-and-accept carve-out, out of my.*).
  build = {
    cfg,
    pkgs,
    lib,
    theme ? null,
    ...
  }:
    if cfg.package == null
    then pkgs.emptyDirectory
    else let
      themedSettings = lib.optionalAttrs (theme != null) {
        theme = polarityTheme (theme.polarity or "dark");
      };
      finalSettings = themedSettings // cfg.settings;
      settingsFile = jsonFormat.generate "claude-code-settings.json" finalSettings;
    in
      pkgs.mkWrapped {
        pkg = cfg.package;
        name = "claude";
        flags = lib.optionals (finalSettings != {}) ["--settings" "${settingsFile}"];
      };
}
