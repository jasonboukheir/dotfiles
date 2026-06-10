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
      # A command outside jj's builtin merge-tools table gets the default
      # merge-args ($left $base $right $output) — a bare editor just opens four
      # buffers. The vim family rides the builtin vimdiff tool (real 3-way
      # invocation) with only its program repointed; anything else stays
      # editor-only.
      isVimFamily = lib.elem (editor.meta.mainProgram or (lib.getName editor)) ["nvim" "vim"];
    in
      # ui assembled in one piece: a top-level `//` would replace the whole
      # `ui` attrset and silently drop ui.editor.
      {ui = {editor = exe;} // (lib.optionalAttrs isVimFamily {merge-editor = "vimdiff";});}
      // (lib.optionalAttrs isVimFamily {merge-tools.vimdiff.program = exe;})));

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
