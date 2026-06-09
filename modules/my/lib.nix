# Framework for the `my.*` program surface. Turns the program definitions in
# ./programs into a shared submodule type and the helpers the platform modules
# (./system-scope.nix, ./home-manager.nix) use to cascade, theme, build, and
# install. See ./programs/CONTRACT.md.
{
  lib,
  pkgs,
}: let
  defs = import ./programs {inherit lib pkgs;};

  # Per-leaf `mkDefault`: recurse an attrset and wrap each leaf, stopping at
  # derivations (so a `package` option is a leaf, not descended into). This is
  # what makes the cascade deep-merge nested `settings` while letting the user
  # win on scalars — a whole-attrset mkDefault would be dropped wholesale.
  recursiveMkDefault =
    lib.mapAttrsRecursiveCond
    (as: !(lib.isDerivation as))
    (_path: value: lib.mkDefault value);

  # Resolve a stylix-ish config + base16 palette into the `theme` passed to a
  # themeable tool's `build`. Returns null when stylix isn't enabled, so a host
  # with no stylix is a no-op.
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

  # Options for one tool's submodule (under my.<name>). The framework owns
  # enable/package/finalPackage/stylix.enable; the def supplies the rest.
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

  # The shared submodule type used for BOTH the system scope (my.*) and the
  # per-user scope (users.users.<n>.my.*).
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

  # Whether a tool should be themed in a given scope, and with which theme.
  themeFor = def: scopeMy: toolCfg: theme:
    if (def.themeable or false) && (scopeMy.stylix.enable or false) && (toolCfg.stylix.enable or true)
    then theme
    else null;

  # Invoke a def's build with the resolved cfg (finalPackage stripped to avoid
  # forcing it) and context.
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
