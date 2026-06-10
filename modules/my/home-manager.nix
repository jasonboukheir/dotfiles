# home-manager entry point for my.*, for the standalone-HM hosts (no system
# layer). Single-user: only the system scope (my.<tool>) -> home.packages.
{
  config,
  lib,
  pkgs,
  neovimConfiguration ? null,
  ...
}: let
  my = import ./lib.nix {inherit lib pkgs;};
  inherit (my) defs myType mkTheme themeFor buildTool settingsDefaultsFor;

  specialArgs = {inherit neovimConfiguration;};

  systemStylix =
    if config ? stylix
    then config.stylix
    else {};

  theme = mkTheme {
    stylixCfg = systemStylix;
    colors =
      if (config ? lib && config.lib ? stylix && config.lib.stylix ? colors)
      then lib.filterAttrs (_: lib.isString) config.lib.stylix.colors
      else {};
  };
in {
  options.my = lib.mkOption {
    type = myType;
    default = {};
  };

  # finalPackage unconditional (lazy); only the install is gated. See the
  # recursion note in ./system-scope.nix.
  config = lib.mkMerge [
    {my.stylix.enable = lib.mkDefault (systemStylix.enable or false);}
    {
      # TODO: the identity/editor knobs (./users/{identity,editor}.nix) only
      # exist on the system scopes — they hang off users.users.<n>, which
      # standalone HM doesn't have. Until HM-scope equivalents are added,
      # git/jj here fall back to unset user.{name,email} and editor fields.
      my = settingsDefaultsFor {
        scopeMy = config.my;
        scopeTheme = theme;
      };
    }
    {
      my =
        lib.mapAttrs (toolName: def: {
          finalPackage = buildTool {
            inherit def specialArgs;
            theme = themeFor def config.my config.my.${toolName} theme;
            toolCfg = config.my.${toolName};
          };
        })
        defs;
    }
    {
      home.packages =
        lib.concatLists (lib.mapAttrsToList (toolName: _def:
          lib.optional config.my.${toolName}.enable config.my.${toolName}.finalPackage)
        defs);

      assertions =
        lib.concatLists (lib.mapAttrsToList (toolName: def:
          lib.optionals (config.my.${toolName}.enable && def ? assertions) (def.assertions {
            inherit specialArgs lib;
            cfg = config.my.${toolName};
          }))
        defs);
    }
  ];
}
