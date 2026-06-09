# Applies the options: assembles the nvf settings (the shared config body fed
# the stylix polarity and meta toggle, plus whatever the module system collected
# into `programs.nvf.settings` — notably stylix's nvf target) and builds the
# wrapped neovim package. Shared by the system and home-manager entry points;
# each of those installs `finalPackage` into its respective package set.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.nvf;

  # Stylix feeds the background polarity (#38). Guarded so a host without stylix
  # is a no-op rather than an eval error.
  stylix =
    if config ? stylix
    then config.stylix
    else {};
in {
  config = lib.mkIf cfg.enable {
    programs.nvf.finalPackage = import ./package.nix {
      inherit pkgs;
      inherit (cfg) neovimConfiguration;
      modules = [
        (import ./settings.nix {
          stylixEnabled = stylix.enable or false;
          polarity = stylix.polarity or "dark";
          meta = {inherit (cfg.meta) enable pluginPath;};
        })
        cfg.settings
      ];
    };
  };
}
