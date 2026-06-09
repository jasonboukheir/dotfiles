{
  lib,
  pkgs,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  perUser = {config, ...}: let
    cfg = config.programs.starship;
  in {
    options.programs.starship = {
      enable = lib.mkEnableOption "starship (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "starship" {};

      settings = lib.mkOption {
        type = tomlFormat.type;
        default = {};
        example = {add_newline = false;};
        description = ''
          starship prompt config baked into this user's wrapper via
          STARSHIP_CONFIG. The shell wrappers emit `starship init <shell>`; this
          option only pins the config the wrapped binary reads — see
          docs/WRAPPERS.md.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "starship";
          env.STARSHIP_CONFIG = tomlFormat.generate "starship.toml" cfg.settings;
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
