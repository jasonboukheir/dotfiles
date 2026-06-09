# Shared NixOS + nix-darwin core for the my.* surface. There are two parallel
# scopes, built from the SAME per-scope helpers below:
#
#   - system scope:   my.<tool>            -> environment.systemPackages
#   - per-user scope: users.users.<n>.my.<tool> -> users.users.<n>.packages,
#                     with its options cascading from the system scope.
#
# Imported by ./nixos.nix and ./nix-darwin.nix. `neovimConfiguration` arrives as
# a specialArg (set per-configuration in the flake partitions); null when unset,
# fine until a host enables my.nvf. See ./programs/CONTRACT.md.
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

  # The system scope's resolved stylix theme (base16 palette + polarity/etc).
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

  # A user's resolved stylix theme, from the per-user stylix surface
  # (modules/stylix/users), which itself defaults from the system stylix.
  userTheme = userCfg:
    mkTheme {
      stylixCfg = userCfg.stylix or {};
      colors = userCfg.stylix.colors or {};
    };

  # ── Per-scope helpers (used identically by both scopes) ──────────────────
  # `scopeMy` is the scope's `my` config (config.my for system, userCfg.my for a
  # user); `scopeTheme` its resolved stylix theme.

  # `finalPackage` for every tool, my-shaped: { <tool> = { finalPackage = …; } }.
  # UNCONDITIONAL (lazy) on purpose: a disabled tool never forces `build`. Gating
  # it with `mkIf …enable` *inside* the `my` submodule would make the submodule's
  # unmatched-definition check force the condition while computing the submodule
  # → infinite recursion. Only the install (below) is gated on enable.
  finalPackageDefs = scopeMy: scopeTheme:
    lib.mapAttrs (toolName: def: {
      finalPackage = buildTool {
        inherit def specialArgs;
        theme = themeFor def scopeMy scopeMy.${toolName} scopeTheme;
        toolCfg = scopeMy.${toolName};
      };
    })
    defs;

  # The enabled tools' finalPackages in a scope — the list to install.
  installFor = scopeMy:
    lib.concatLists (lib.mapAttrsToList (toolName: _def:
      lib.optional scopeMy.${toolName}.enable scopeMy.${toolName}.finalPackage)
    defs);

  # Assertions declared by the scope's enabled tools (e.g. nvf's specialArg).
  assertionsFor = scopeMy:
    lib.concatLists (lib.mapAttrsToList (toolName: def:
      lib.optionals (scopeMy.${toolName}.enable && def ? assertions) (def.assertions {
        inherit specialArgs lib;
        cfg = scopeMy.${toolName};
      }))
    defs);

  # Per-user options default-cascade from the system scope: every non-enable,
  # non-finalPackage option as a per-leaf mkDefault (deep-merge; user wins).
  # enable stays its own default (false) so a system-enabled tool doesn't fan a
  # copy into every user. Read from the *system* `config.my`.
  cascadeFromSystem =
    lib.mapAttrs (toolName: _def:
      recursiveMkDefault (removeAttrs config.my.${toolName} ["enable" "finalPackage"]))
    defs;

  # The submodule applied to EVERY users.users.<name> (wired as the type of
  # options.users.users below). This is where the per-user scope lives.
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
