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
