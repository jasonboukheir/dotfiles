{
  lib,
  pkgs,
}: let
  defs = import ./programs {inherit lib pkgs;};

  # Per-leaf (stops at derivations) so the cascade deep-merges nested settings
  # and lets the user win on scalars; a whole-attrset mkDefault is dropped whole.
  recursiveMkDefault =
    lib.mapAttrsRecursiveCond
    (as: !(lib.isDerivation as))
    (_path: value: lib.mkDefault value);

  mkTheme = {
    stylixCfg ? {},
    colors ? {},
  }:
    if !(stylixCfg.enable or false)
    then null
    else {
      inherit colors;
      polarity = stylixCfg.polarity or "dark";
      fonts = stylixCfg.fonts or {};
      opacity = stylixCfg.opacity or {};
    };

  toolOptions = def:
    {
      enable = lib.mkEnableOption "${def.name} (my.* wrapped package) in this environment";

      finalPackage = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "The built ${def.name} package (read-only; set by the platform module).";
      };
    }
    // lib.optionalAttrs ((def.defaultPackage or null) != null) {
      package = lib.mkPackageOption pkgs def.defaultPackage {};
    }
    // lib.optionalAttrs (def.themeable or false) {
      stylix.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Theme this ${def.name} from stylix when the my.* stylix integration (my.stylix.enable) is on.";
      };
    }
    // (def.options or {});

  myType = lib.types.submodule {
    options =
      {
        stylix.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Master toggle for the my.* <-> stylix theming integration. Defaults to the host's stylix.enable.";
        };
      }
      // lib.mapAttrs (
        _name: def:
          lib.mkOption {
            type = lib.types.submodule {options = toolOptions def;};
            default = {};
            description = "my.${def.name} program (disabled by default).";
          }
      )
      defs;
  };

  themeFor = def: scopeMy: toolCfg: theme:
    if (def.themeable or false) && (scopeMy.stylix.enable or false) && (toolCfg.stylix.enable or true)
    then theme
    else null;

  buildTool = {
    def,
    toolCfg,
    theme,
    specialArgs,
  }:
    def.build {
      cfg = removeAttrs toolCfg ["finalPackage"];
      inherit pkgs lib theme specialArgs;
    };
in {
  inherit defs myType recursiveMkDefault mkTheme themeFor buildTool;
}
