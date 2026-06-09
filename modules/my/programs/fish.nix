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
    # vendor_conf.d is sourced explicitly: prepending the search path alone does
    # not auto-source conf.d fish has already scanned.
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
    # TODO(#42): vendor-completion parity relies on plugins shipping
    # vendor_completions.d; carapace/vivid from the old system module aren't
    # reproduced here yet.
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "fish";
      env.__fish_config_dir = "${confD}";
      extraPaths = cfg.plugins;
    };
}
