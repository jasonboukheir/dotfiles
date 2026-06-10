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
      # Keep only the base16 palette slots; stylix's colors attr also carries
      # string metadata (author/scheme/slug) that consumers like nvf's
      # base16-colors reject.
      colors = lib.filterAttrs (name: _: lib.match "base0[0-9A-Fa-f]" name != null) colors;
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

  # The full set of inputs a def's `build` ever receives. There is deliberately
  # no `config` here: defs are imported as pure `{lib, pkgs}` functions (see
  # ./programs/default.nix), so a build that reads ambient module config can't
  # be written — purity is enforced by config's absence from scope, not by
  # convention. `build` renders the already-resolved `cfg.settings`; the
  # framework folds theme/identity/editor defaults into that option beforehand
  # (see settingsDefaultsFor), so build does no merging of its own.
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

  # Framework-injected option defaults: each def's `settingsDefaults` maps the
  # trimmed per-scope view (theme/identity/editor — never full config) to that
  # tool's settings schema, and the result is fed in as `recursiveMkDefault` so
  # the user's own `my.<tool>.settings` (and the system→user cascade) win through
  # the ordinary module-system priority merge. Defs without the hook contribute
  # nothing.
  settingsDefaultsFor = {
    scopeMy,
    scopeTheme,
    identity ? null,
    editor ? null,
  }:
    lib.mapAttrs (
      toolName: def:
        lib.optionalAttrs (def ? settingsDefaults) {
          settings = recursiveMkDefault (def.settingsDefaults {
            theme = themeFor def scopeMy scopeMy.${toolName} scopeTheme;
            inherit identity editor;
          });
        }
    )
    defs;
in {
  inherit defs myType recursiveMkDefault mkTheme themeFor buildTool settingsDefaultsFor;
}
