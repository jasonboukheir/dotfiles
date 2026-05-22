{
  config,
  lib,
  ...
}: let
  cfg = config.stylix;
  claudeCodeTheme =
    if cfg.polarity == "light"
    then "light-ansi"
    else "dark-ansi";
in {
  config = lib.mkIf cfg.enable {
    programs.claude-code.settings.theme = lib.mkDefault claudeCodeTheme;
  };
}
