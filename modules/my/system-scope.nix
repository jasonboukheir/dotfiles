# Shared NixOS + nix-darwin core for the my.* surface. Declares the system scope
# (my.<tool> -> environment.systemPackages) and the per-user scope
# (users.users.<n>.my.<tool> -> users.users.<n>.packages, cascading from the
# system scope). Imported by ./nixos.nix and ./nix-darwin.nix.
#
# `neovimConfiguration` arrives as a specialArg (set per-configuration in the
# flake partitions); it's null when unset, which is fine until a host enables
# my.nvf. See ./programs/CONTRACT.md.
{
  config,
  lib,
  pkgs,
  neovimConfiguration ? null,
  ...
}: let
  my = import ./lib.nix {inherit lib pkgs;};
  inherit (my) defs myType recursiveMkDefault mkTheme themeFor buildTool;

  specialArgs = {inherit neovimConfiguration;};

  systemStylix =
    if config ? stylix
    then config.stylix
    else {};

  systemTheme = mkTheme {
    stylixCfg = systemStylix;
    colors =
      if (config ? lib && config.lib ? stylix && config.lib.stylix ? colors)
      then lib.filterAttrs (_: lib.isString) config.lib.stylix.colors
      else {};
  };

  # Capture the system-scope config for cascade inside the per-user submodule.
  outerConfig = config;

  # `finalPackage` is defined UNCONDITIONALLY (it's lazy, so a disabled tool
  # never forces `build`). Gating it with `mkIf …enable` inside the `my`
  # submodule would make the submodule's unmatched-definition check force the
  # condition while computing the submodule → infinite recursion. Only the
  # install (a top-level option) is gated on enable.
  perUser = userArgs: {
    options.my = lib.mkOption {
      type = myType;
      default = {};
    };

    config = let
      userCfg = userArgs.config;
      userTheme = mkTheme {
        stylixCfg = userCfg.stylix or {};
        colors = userCfg.stylix.colors or {};
      };
    in
      lib.mkMerge (
        # cascade the my.stylix master toggle
        [{my.stylix.enable = lib.mkDefault outerConfig.my.stylix.enable;}]
        ++ lib.mapAttrsToList (
          toolName: def: {
            # cascade every non-enable/finalPackage option as per-leaf mkDefault
            my.${toolName} =
              recursiveMkDefault
              (removeAttrs outerConfig.my.${toolName} ["enable" "finalPackage"])
              // {
                finalPackage = buildTool {
                  inherit def specialArgs;
                  theme = themeFor def userCfg.my userCfg.my.${toolName} userTheme;
                  toolCfg = userCfg.my.${toolName};
                };
              };

            packages = lib.optional userCfg.my.${toolName}.enable userCfg.my.${toolName}.finalPackage;
          }
        )
        defs
      );
  };
in {
  options.my = lib.mkOption {
    type = myType;
    default = {};
  };

  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };

  config = lib.mkMerge (
    [
      {my.stylix.enable = lib.mkDefault (systemStylix.enable or false);}
      {
        my =
          lib.mapAttrs (toolName: def: {
            finalPackage = buildTool {
              inherit def specialArgs;
              theme = themeFor def config.my config.my.${toolName} systemTheme;
              toolCfg = config.my.${toolName};
            };
          })
          defs;
      }
      {
        environment.systemPackages =
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
    ]
  );
}
