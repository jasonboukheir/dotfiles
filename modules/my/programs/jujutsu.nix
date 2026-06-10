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

  # Mapped from the per-user identity/editor into jj's schema; injected as
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
      ui.editor = exe;
      ui.merge-editor = exe;
    }));

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
