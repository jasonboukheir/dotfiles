{
  lib,
  pkgs,
}: let
  yamlFormat = pkgs.formats.yaml {};
in {
  name = "gh";
  defaultPackage = "gh";

  options = {
    settings = lib.mkOption {
      type = yamlFormat.type;
      default = {};
      example = {editor = "nvim";};
      description = ''
        gh config. Only `editor` is baked (pinned as GH_EDITOR); the rest of
        gh's config and its auth (hosts.yml) stay in the real GH_CONFIG_DIR so
        `gh auth login` keeps working.
      '';
    };
  };

  # Mapped from the per-user editor into gh's `editor` setting; injected below
  # the cascade's mkDefault (see settingsDefaultsFor) so an explicit
  # settings.editor and the system→user cascade win.
  settingsDefaults = {
    editor ? null,
    ...
  }:
    lib.optionalAttrs (editor != null) {editor = lib.getExe editor;};

  build = {
    cfg,
    pkgs,
    ...
  }:
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "gh";
      env = lib.optionalAttrs (cfg.settings ? editor) {
        GH_EDITOR = cfg.settings.editor;
      };
    };
}
