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
  my = import ./lib {inherit lib pkgs;};
  inherit (my) defs myType recursiveMkDefault mkTheme themeFor buildTool settingsDefaultsFor;

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

  # A def may carry an `etc` hook mapping its resolved cfg to environment.etc
  # entries (e.g. a browser's managed-policy file). Collected from every enabled
  # tool in a scope; merged across all scopes below. The hook reads `lib`/`pkgs`
  # from the def's own closure, so it only needs `cfg`.
  etcFor = scopeMy:
    lib.mkMerge (lib.concatLists (lib.mapAttrsToList (toolName: def:
      lib.optional (def ? etc && scopeMy.${toolName}.enable)
      (def.etc {cfg = removeAttrs scopeMy.${toolName} ["finalPackage"];}))
    defs));

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
      {
        my = settingsDefaultsFor {
          scopeMy = userCfg.my;
          scopeTheme = userTheme userCfg;
          inherit (userCfg) identity editor;
        };
      }
      {my = finalPackageDefs userCfg.my (userTheme userCfg);}
      {packages = installFor userCfg.my;}
    ];
  };
in {
  # Per-user identity/editor knobs. Each program def maps them (and the resolved
  # stylix theme) into its own settings schema via `settingsDefaults`, which the
  # framework folds in below mkDefault (see settingsDefaultsFor) — so the
  # consuming logic stays in the pure program defs while the user's settings and
  # the system→user cascade still win.
  imports = [
    ./users/identity.nix
    ./users/editor.nix
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
    {
      my = settingsDefaultsFor {
        scopeMy = config.my;
        scopeTheme = systemTheme;
      };
    }
    {my = finalPackageDefs config.my systemTheme;}
    {
      environment.systemPackages = installFor config.my;
      assertions = assertionsFor config.my;
    }
    {
      # Managed policy and other /etc state is system-global, so def `etc`
      # contributions from the per-user scopes surface here at the system level.
      environment.etc = lib.mkMerge (
        [(etcFor config.my)]
        ++ lib.mapAttrsToList (_name: userCfg: etcFor userCfg.my) config.users.users
      );
    }
  ];
}
