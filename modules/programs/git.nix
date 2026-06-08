{
  lib,
  pkgs,
  ...
}: let
  gitIniFormat = pkgs.formats.gitIni {};

  lfsFilter = {
    clean = "git-lfs clean -- %f";
    smudge = "git-lfs smudge -- %f";
    process = "git-lfs filter-process";
    required = true;
  };

  perUser = {config, ...}: let
    cfg = config.programs.git;
    excludesFile = pkgs.writeText "gitignore" (lib.concatStringsSep "\n" cfg.ignores);
    bakedConfig = lib.foldl' lib.recursiveUpdate {} [
      cfg.settings
      (lib.optionalAttrs (cfg.ignores != []) {core.excludesFile = "${excludesFile}";})
      (lib.optionalAttrs cfg.lfs.enable {filter.lfs = lfsFilter;})
    ];
  in {
    options.programs.git = {
      enable = lib.mkEnableOption "git (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "git" {};

      lfs.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Put git-lfs on the wrapper PATH and bake its filters into GIT_CONFIG_GLOBAL.";
      };

      ignores = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [".DS_Store"];
        description = "Patterns baked into a gitignore and wired as core.excludesFile.";
      };

      settings = lib.mkOption {
        type = gitIniFormat.type;
        default = {};
        example = {init.defaultBranch = "main";};
        description = "Settings baked into this user's git wrapper via GIT_CONFIG_GLOBAL.";
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "git";
          extraPaths = lib.optional cfg.lfs.enable pkgs.git-lfs;
          env.GIT_CONFIG_GLOBAL = gitIniFormat.generate "gitconfig" bakedConfig;
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };

  config.programs.git = {
    enable = lib.mkDefault true;
    lfs.enable = true;
  };
}
