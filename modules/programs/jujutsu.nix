{
  lib,
  pkgs,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  perUser = {config, ...}: let
    cfg = config.programs.jujutsu;
  in {
    options.programs.jujutsu = {
      enable = lib.mkEnableOption "jujutsu (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "jujutsu" {};

      settings = lib.mkOption {
        type = tomlFormat.type;
        default = {};
        example = {ui.editor = "nvim";};
        description = "Settings baked into this user's jj wrapper via JJ_CONFIG.";
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "jj";
          env.JJ_CONFIG = tomlFormat.generate "jj-config.toml" cfg.settings;
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
