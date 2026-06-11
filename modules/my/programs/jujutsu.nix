{
  lib,
  pkgs,
}: let
  tomlFormat = pkgs.formats.toml {};
in {
  name = "jujutsu";
  defaultPackage = "jujutsu";

  options = {
    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      example = {ui.editor = "nvim";};
      description = "Settings baked into this jj wrapper via JJ_CONFIG.";
    };
  };

  # Mapped from the per-user identity/editor into jj's schema; injected below
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
      # jj hands its editors on-disk paths ($left/$base/$right/$output), not
      # revs. nvim rides diffview-plus.nvim (baked into the nvf editor build,
      # see nvf/body.nix): :DiffviewMergeFiles for the 3-way merge editor and
      # :DiffviewDiffDirs for the interactive diff editor, both VCS-less.
      # Plain vim falls back to jj's builtin vimdiff tool with only its program
      # repointed; anything else (a bare editor) stays editor-only.
      mainProgram = editor.meta.mainProgram or (lib.getName editor);

      # merge-tool-edits-conflict-markers: jj pre-fills $output with conflict
      # markers and reparses them on exit, so a partial resolve is preserved.
      diffviewTooling = {
        ui = {
          merge-editor = "diffview";
          diff-editor = "diffview";
        };
        merge-tools.diffview = {
          program = exe;
          merge-args = ["-c" "DiffviewMergeFiles $output $base $left $right"];
          merge-tool-edits-conflict-markers = true;
          edit-args = ["-c" "DiffviewDiffDirs $left $right $output"];
          diff-args = ["-c" "DiffviewDiffDirs $left $right"];
        };
      };

      vimdiffTooling = {
        ui.merge-editor = "vimdiff";
        merge-tools.vimdiff.program = exe;
      };

      editorTooling =
        if mainProgram == "nvim"
        then diffviewTooling
        else if mainProgram == "vim"
        then vimdiffTooling
        else {};
    in
      # ui assembled in one piece: a top-level `//` would replace the whole
      # `ui` attrset and silently drop ui.editor.
      lib.recursiveUpdate {ui.editor = exe;} editorTooling));

  build = {
    cfg,
    pkgs,
    ...
  }:
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "jj";
      env.JJ_CONFIG = tomlFormat.generate "jj-config.toml" cfg.settings;
    };
}
