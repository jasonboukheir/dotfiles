{
  lib,
  pkgs,
}: let
  gitIniFormat = pkgs.formats.gitIni {};

  lfsFilter = {
    clean = "git-lfs clean -- %f";
    smudge = "git-lfs smudge -- %f";
    process = "git-lfs filter-process";
    required = true;
  };
in {
  name = "git";
  defaultPackage = "git";

  options = {
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
      description = "Settings baked into this git wrapper via GIT_CONFIG_GLOBAL.";
    };
  };

  # Mapped from the per-user identity/editor into git's schema; injected as
  # mkDefault so the user's own settings win.
  settingsDefaults = {
    identity ? null,
    editor ? null,
    ...
  }:
    (lib.optionalAttrs (identity != null) {
      user =
        (lib.optionalAttrs (identity.name != null) {name = identity.name;})
        // (lib.optionalAttrs (identity.email != null) {email = identity.email;});
    })
    // (lib.optionalAttrs (editor != null) (let
      exe = lib.getExe editor;
    in {
      core.editor = exe;
      merge.tool = exe;
      diff.tool = exe;
    }));

  build = {
    cfg,
    pkgs,
    ...
  }: let
    excludesFile = pkgs.writeText "gitignore" (lib.concatStringsSep "\n" cfg.ignores);
    bakedConfig = lib.foldl' lib.recursiveUpdate {} [
      cfg.settings
      (lib.optionalAttrs (cfg.ignores != []) {core.excludesFile = "${excludesFile}";})
      (lib.optionalAttrs cfg.lfs.enable {filter.lfs = lfsFilter;})
    ];
  in
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "git";
      extraPaths = lib.optional cfg.lfs.enable pkgs.git-lfs;
      env.GIT_CONFIG_GLOBAL = gitIniFormat.generate "gitconfig" bakedConfig;
    };
}
