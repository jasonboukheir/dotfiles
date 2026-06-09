{
  lib,
  pkgs,
}: let
  tomlFormat = pkgs.formats.toml {};
in {
  name = "starship";
  defaultPackage = "starship";

  options = {
    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      example = {add_newline = false;};
      description = ''
        starship prompt config baked into this wrapper via STARSHIP_CONFIG. The
        shell wrappers emit `starship init <shell>`; this option only pins the
        config the wrapped binary reads.
      '';
    };
  };

  build = {
    cfg,
    pkgs,
    ...
  }:
    pkgs.mkWrapped {
      pkg = cfg.package;
      name = "starship";
      env.STARSHIP_CONFIG = tomlFormat.generate "starship.toml" cfg.settings;
    };
}
