{
  lib,
  pkgs,
  ...
}: let
  renderValue = v:
    if lib.isBool v
    then lib.boolToString v
    else toString v;

  renderEntry = key: value:
    if lib.isList value
    then map (item: "${key} = ${renderValue item}") value
    else ["${key} = ${renderValue value}"];

  renderConfig = settings:
    lib.concatStringsSep "\n" (lib.concatLists (lib.mapAttrsToList renderEntry settings)) + "\n";

  perUser = {config, ...}: let
    cfg = config.programs.ghostty;
    configFile = pkgs.writeText "ghostty-config" (renderConfig cfg.settings);
  in {
    options.programs.ghostty = {
      enable = lib.mkEnableOption "ghostty (hand-rolled wrapper) in this user's environment";

      package = lib.mkPackageOption pkgs "ghostty" {};

      settings = lib.mkOption {
        type = with lib.types; attrsOf (oneOf [bool int str (listOf str)]);
        default = {};
        example = {
          theme = "GruvboxDark";
          palette = ["0=#1d2021" "1=#cc241d"];
        };
        description = ''
          ghostty config baked into this user's wrapper and loaded via
          `--config-file`. List values render as repeated `key = item` lines
          (e.g. `palette`). The stylix target under `modules/stylix/users`
          populates the color keys; the user's own `~/.config/ghostty/config`
          still loads and wins on conflicts.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      packages = [
        (pkgs.mkWrapped {
          pkg = cfg.package;
          name = "ghostty";
          flags = lib.optional (cfg.settings != {}) "--config-file=${configFile}";
        })
      ];
    };
  };
in {
  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };
}
