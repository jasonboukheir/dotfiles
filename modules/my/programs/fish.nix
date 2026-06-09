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
        Fish snippet shipped as this wrapper's last vendor_conf.d entry, so it is
        sourced on every session start (e.g. starship/direnv hooks). Replaces the
        OLD native programs.fish.interactiveShellInit.
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[ pkgs.fishPlugins.plugin-git ]";
      description = ''
        Fish plugin packages to bundle into this wrapper. Their
        vendor_completions.d / vendor_functions.d / vendor_conf.d are merged into
        the wrapper's share/fish so fish discovers them from the user's nix
        profile (replaces the OLD system-profile vendor loading).
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    lib,
    ...
  }: let
    # nixpkgs fish discovers vendor dirs (vendor_conf.d sourced, vendor_functions.d
    # / vendor_completions.d autoloaded) from each nix profile in $NIX_PROFILES —
    # NOT from the $__fish_config_dir env var (fish 4.x ignores it) or XDG_DATA_DIRS.
    # So this wrapper contributes its config as share/fish/vendor_*; once it lands
    # on the user's profile, fish picks it up. The plugins' own vendor dirs are
    # copied in for the same reason.
    initFile = pkgs.writeText "zz-my-init.fish" cfg.interactiveShellInit;
    configPkg = pkgs.runCommand "my-fish-config" {} ''
      mkdir -p $out/share/fish/vendor_conf.d \
               $out/share/fish/vendor_functions.d \
               $out/share/fish/vendor_completions.d \
               $out/share/my-fish/functions
      ${lib.concatMapStringsSep "\n" (p: ''
        for d in vendor_functions.d vendor_completions.d vendor_conf.d; do
          if [ -d ${p}/share/fish/$d ]; then
            cp -n ${p}/share/fish/$d/*.fish $out/share/fish/$d/ 2>/dev/null || true
          fi
        done
        if [ -d ${p}/share/fish/vendor_functions.d ]; then
          cp -n ${p}/share/fish/vendor_functions.d/*.fish $out/share/my-fish/functions/ 2>/dev/null || true
        fi
      '') cfg.plugins}
      # Fisher-style plugins (e.g. plugin-git's gss/gco/... abbreviations) only
      # initialise when they find $fisher_path/functions/<init>.fish as a real
      # file. fish has no fisher_path, so point it at the copied functions; the
      # 00- prefix sorts this conf.d before the plugins' own.
      echo "set -g fisher_path $out/share/my-fish" > $out/share/fish/vendor_conf.d/00-my-fisher-path.fish
      # User init (starship/direnv/...) runs last so it can override plugin setup.
      cp ${initFile} $out/share/fish/vendor_conf.d/zz-my-init.fish
    '';
  in
    # TODO(#42): vendor-completion parity relies on plugins shipping
    # vendor_completions.d; carapace/vivid from the old system module aren't
    # reproduced here yet.
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "fish";
      extraMerge = [configPkg];
      extraPaths = cfg.plugins;
    };
}
