{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.programs.nushell.vivid;
in {
  options = {
    programs.nushell.vivid = {
      enable = mkEnableOption "Enable vivid integration for nushell";
      pkg = mkOption {
        type = types.nullOr types.package;
        default = pkgs.vivid;
        description = "Package to use for vivid";
      };
      theme = mkOption {
        type = types.str;
        description = "Theme name to use with vivid generate";
        example = "gruvbox-dark";
      };
    };
  };

  config = mkIf cfg.enable {
    # Validation: theme must be set if enabled
    assertions = [
      {
        assertion = cfg.theme != null && cfg.theme != "";
        message = "programs.nushell.vivid.theme must be set if enable is true";
      }
    ];

    home.packages = lib.optional (cfg.pkg != null) cfg.pkg;

    programs.nushell.extraConfig = ''
      $env.LS_COLORS = (${cfg.pkg}/bin/vivid generate ${cfg.theme})
    '';
  };
}
