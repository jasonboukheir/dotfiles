# home-manager entry point for the my.* surface, for the standalone-HM hosts
# (work-devserver, jasonbk-fedora) which have no system layer. A standalone host
# is effectively single-user, so it exposes only the system scope (my.<tool>) and
# installs finalPackage into home.packages. Hosts with a system layer use
# ./nixos.nix / ./nix-darwin.nix instead.
{
  config,
  lib,
  pkgs,
  neovimConfiguration ? null,
  ...
}: let
  my = import ./lib.nix {inherit lib pkgs;};
  inherit (my) defs myType mkTheme themeFor buildTool;

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

  # finalPackage is unconditional (lazy); only the install + assertions are gated
  # on enable. See the note in ./system-scope.nix on why gating finalPackage
  # inside the `my` submodule causes infinite recursion.
  config = lib.mkMerge [
    {my.stylix.enable = lib.mkDefault (systemStylix.enable or false);}
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
