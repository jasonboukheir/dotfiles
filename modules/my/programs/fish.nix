# Program definition for a per-user WRAPPED fish (my.fish). Replaces the OLD
# native programs.fish system module: instead of system-wide interactiveShellInit
# + system-profile vendor loading, this bakes a private config dir (pointed at via
# $__fish_config_dir) carrying the init hooks and plugin vendor-path wiring, so a
# single user gets a configured fish on PATH without any system fish module.
# See ./CONTRACT.md and docs/plans/2026-06-09-my-namespace-wrappers-design-final.md
# ("fish & direnv").
{
  lib,
  pkgs,
}: {
  name = "fish";
  defaultPackage = "fish";

  options = {
    interactiveShellInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        starship init fish | source
        direnv hook fish | source
      '';
      description = ''
        Fish snippet baked into this wrapper's conf.d, sourced on every
        interactive session start (e.g. starship/direnv hooks). Replaces the
        OLD native programs.fish.interactiveShellInit.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.fishPlugins.plugin-git ]";
      description = ''
        Fish plugin packages whose share/fish/vendor_* dirs should resolve in
        this wrapper. Their vendor_completions.d / vendor_functions.d /
        vendor_conf.d are prepended onto fish's search paths via a baked conf.d
        snippet (replaces the OLD system-profile vendor loading).
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    # Prepend each plugin's vendor dirs onto fish's search/source paths. fish has
    # no env-var equivalent for these, so we emit a conf.d snippet that runs
    # before user config (conf.d files are sourced in alphabetical order, hence
    # the 00- prefix). vendor_conf.d files are sourced explicitly since adding to
    # a search path alone does not auto-source already-loaded conf.d.
    pluginVendorSnippet = let
      forPlugin = p: ''
        if test -d ${p}/share/fish/vendor_completions.d
            set -p fish_complete_path ${p}/share/fish/vendor_completions.d
        end
        if test -d ${p}/share/fish/vendor_functions.d
            set -p fish_function_path ${p}/share/fish/vendor_functions.d
        end
        if test -d ${p}/share/fish/vendor_conf.d
            for __my_fish_conf in ${p}/share/fish/vendor_conf.d/*.fish
                source $__my_fish_conf
            end
        end
      '';
    in
      lib.concatMapStringsSep "\n" forPlugin cfg.plugins;

    confD = pkgs.linkFarm "my-fish-conf.d" [
      {
        name = "conf.d/00-my-plugins.fish";
        path = pkgs.writeText "00-my-plugins.fish" pluginVendorSnippet;
      }
      {
        name = "conf.d/00-my-init.fish";
        path = pkgs.writeText "00-my-init.fish" cfg.interactiveShellInit;
      }
    ];
  in
    # fish reads config.fish/conf.d from $__fish_config_dir (defaults to
    # $XDG_CONFIG_HOME/fish). Setting it via --set points fish at our baked dir
    # without clobbering XDG_CONFIG_HOME / XDG_DATA_DIRS. Plugin packages are also
    # placed on PATH so any binaries they ship resolve.
    # TODO(#42): conf.d-only config dir (no config.fish); vendor-completion parity
    # relies on plugins shipping vendor_completions.d. carapace/vivid/full vendor
    # machinery from the old system module are not yet reproduced here.
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "fish";
      env.__fish_config_dir = "${confD}";
      extraPaths = cfg.plugins;
    };
}
