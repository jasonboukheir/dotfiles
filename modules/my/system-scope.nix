# Shared NixOS + nix-darwin core for my.*: the system scope
# (my.<tool> -> environment.systemPackages) and the per-user scope
# (users.users.<n>.my.<tool> -> users.users.<n>.packages, cascading from system).
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

  userTheme = userCfg:
    mkTheme {
      stylixCfg = userCfg.stylix or {};
      colors = userCfg.stylix.colors or {};
    };

  # finalPackage is UNCONDITIONAL (lazy, so a disabled tool never forces build);
  # gating it inside the `my` submodule makes the submodule's unmatched-def check
  # force the condition while computing the submodule -> infinite recursion. Only
  # the install (below) is gated on enable.
  finalPackageDefs = scopeMy: scopeTheme:
    lib.mapAttrs (toolName: def: {
      finalPackage = buildTool {
        inherit def specialArgs;
        theme = themeFor def scopeMy scopeMy.${toolName} scopeTheme;
        toolCfg = scopeMy.${toolName};
      };
    })
    defs;

  installFor = scopeMy:
    lib.concatLists (lib.mapAttrsToList (toolName: _def:
      lib.optional scopeMy.${toolName}.enable scopeMy.${toolName}.finalPackage)
    defs);

  assertionsFor = scopeMy:
    lib.concatLists (lib.mapAttrsToList (toolName: def:
      lib.optionals (scopeMy.${toolName}.enable && def ? assertions) (def.assertions {
        inherit specialArgs lib;
        cfg = scopeMy.${toolName};
      }))
    defs);

  # TODO: recursiveMkDefault descends into deferredModule options (e.g.
  # my.nvf.settings), wrapping their internal `imports` list in mkDefault, which
  # the inner module system then rejects ("expected a list but found a set").
  # Tools with a deferredModule option therefore only work at the system scope
  # today; enable them via `my.<tool>` rather than `users.users.<n>.my.<tool>`.
  cascadeFromSystem =
    lib.mapAttrs (toolName: _def:
      recursiveMkDefault (removeAttrs config.my.${toolName} ["enable" "finalPackage"]))
    defs;

  # The submodule type of every users.users.<n>: its config is the per-user scope.
  perUser = userArgs: let
    userCfg = userArgs.config;
  in {
    options.my = lib.mkOption {
      type = myType;
      default = {};
    };

    config = lib.mkMerge [
      {my = cascadeFromSystem;}
      {my.stylix.enable = lib.mkDefault config.my.stylix.enable;}
      {my = finalPackageDefs userCfg.my (userTheme userCfg);}
      {packages = installFor userCfg.my;}
    ];
  };
in {
  # Per-user identity/editor knobs and the wiring that defaults each tool's
  # settings from them. Kept out of programs/ (pure build defs) since this reads
  # sibling user config, which the program-definition contract forbids in build.
  imports = [
    ./users/identity.nix
    ./users/editor.nix
    ./git.nix
    ./gh.nix
    ./jujutsu.nix
  ];

  options.my = lib.mkOption {
    type = myType;
    default = {};
  };

  options.users.users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule perUser);
  };

  config = lib.mkMerge [
    {my.stylix.enable = lib.mkDefault (systemStylix.enable or false);}
    {my = finalPackageDefs config.my systemTheme;}
    {
      environment.systemPackages = installFor config.my;
      assertions = assertionsFor config.my;
    }
  ];
}
