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

  # Mapped from the per-user identity/editor into git's schema; injected below
  # the cascade's mkDefault (see settingsDefaultsFor) so explicit settings and
  # the system→user cascade win.
  settingsDefaults = {
    identity ? null,
    editor ? null,
    ...
  }:
    (lib.optionalAttrs (identity != null && (identity.name != null || identity.email != null)) {
      user =
        (lib.optionalAttrs (identity.name != null) {name = identity.name;})
        // (lib.optionalAttrs (identity.email != null) {email = identity.email;});
    })
    // (lib.optionalAttrs (editor != null) (let
      exe = lib.getExe editor;
      # merge.tool/diff.tool take a *tool name* git resolves, not a command.
      # nvim rides diffview-plus.nvim (baked into the nvf editor build, see
      # nvf/body.nix) wired as a cmd-based custom tool; plain vim falls back to
      # git's builtin vimdiff table via {merge,diff}tool.<name>.path. Program
      # name from metadata, not baseNameOf exe: a store-path basename carries
      # string context, which attribute names reject.
      mainProgram = editor.meta.mainProgram or (lib.getName editor);

      # DiffviewOpen auto-detects an in-progress merge and opens its 3-way
      # mergetool view; trustExitCode lets a clean exit mark the file resolved.
      # diffview is rev-range oriented, so per-file `git difftool <rev>` would
      # reopen the same view for every file — `git dv [rev-range]` opens it once.
      diffviewTooling = {
        merge.tool = "diffview";
        mergetool = {
          prompt = false;
          keepBackup = false;
          diffview = {
            cmd = "${exe} -n -c \"DiffviewOpen\" \"$MERGED\"";
            trustExitCode = true;
          };
        };
        diff.tool = "diffview";
        difftool = {
          prompt = false;
          diffview.cmd = "${exe} -n -c \"DiffviewOpen\"";
        };
        alias.dv = "!f() { ${exe} -c \"DiffviewOpen $*\"; }; f";
      };

      vimdiffTooling = {
        merge.tool = "vimdiff";
        mergetool.vimdiff.path = exe;
        diff.tool = "vimdiff";
        difftool.vimdiff.path = exe;
      };

      editorTooling =
        if mainProgram == "nvim"
        then diffviewTooling
        else if mainProgram == "vim"
        then vimdiffTooling
        else {};
    in
      {core.editor = exe;} // editorTooling));

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
