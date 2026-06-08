{
  lib,
  pkgs,
  ...
}: let
  yamlFormat = pkgs.formats.yaml {};

  perUser = {config, ...}: let
    cfg = config.programs.gh;
  in {
    options.programs.gh = {
      enable = lib.mkEnableOption "gh (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "gh" {};

      settings = lib.mkOption {
        type = yamlFormat.type;
        default = {};
        example = {editor = "nvim";};
        description = ''
          gh config. Only `editor` is baked (pinned as GH_EDITOR); the rest of
          gh's config and its auth (hosts.yml) stay in the real GH_CONFIG_DIR so
          `gh auth login` keeps working — see docs/WRAPPERS.md.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "gh";
          env = lib.optionalAttrs (cfg.settings ? editor) {
            GH_EDITOR = cfg.settings.editor;
          };
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
