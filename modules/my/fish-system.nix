# Fish's nix-environment system wiring for the my.* wrapper, shared by the NixOS
# and nix-darwin entry points (config.system.build.setEnvironment exists on both).
#
# my.* program defs set no system state (they only build a package), so this
# lives in a platform-imported module rather than modules/my/programs/fish.nix. It is
# the self-contained replacement for piggybacking on the native programs.fish
# module (https://github.com/jasonboukheir/dotfiles/issues/69).
#
# Mechanism: every nixpkgs fish is built useOperatingSystemEtc and bakes
# share/fish/__fish_build_paths.fish, which sources /etc/fish/nixos-env-preinit.fish
# at startup iff that file exists. The my.fish wrapper wraps that same fish, so
# writing the preinit here is all that is needed to inject the nix environment
# (/run/current-system/sw/bin + per-user profiles) onto a fish login shell's PATH.
# The wrapper bakes its own plugins + interactiveShellInit into vendor_conf.d
# (loaded via $NIX_PROFILES), so no /etc/fish/config.fish is required.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge mkForce filter attrValues optional getExe';

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  perUserFish =
    map (u: u.my.fish.finalPackage)
    (filter (u: u.my.fish.enable) (attrValues config.users.users));

  # System scope first, then every per-user login-shell wrapper. The env wiring
  # itself is global and identical for all of them, so the multi-user story is
  # unambiguous (unlike picking a single programs.fish.package).
  allFish = optional config.my.fish.enable config.my.fish.finalPackage ++ perUserFish;

  # setEnvironment marks completion with a platform-specific sentinel; matching it
  # lets a login shell skip a redundant re-source (parity with the native module).
  envDoneVar =
    if isDarwin
    then "__NIX_DARWIN_SET_ENVIRONMENT_DONE"
    else "__NIXOS_SET_ENVIRONMENT_DONE";
in {
  config = mkMerge [
    (mkIf (allFish != []) {
      # Non-babelfish preinit body mirroring nixpkgs programs/fish.nix: fenv evals
      # the POSIX setEnvironment (fish cannot source sh natively).
      environment.etc."fish/nixos-env-preinit.fish".text = ''
        set fish_function_path ${pkgs.fishPlugins.foreign-env}/share/fish/vendor_functions.d
        if [ -z "''$${envDoneVar}" ]
          fenv source ${config.system.build.setEnvironment}
        end
        set -e fish_function_path
      '';

      environment.shells = map (p: getExe' p "fish") allFish;

      # Let packages that ship fish vendor files land in the system profile so a
      # fish session discovers them via $NIX_PROFILES (the wrapper bakes its own).
      environment.pathsToLink = [
        "/share/fish/vendor_conf.d"
        "/share/fish/vendor_completions.d"
        "/share/fish/vendor_functions.d"
      ];
    })

    # On darwin, a host-enabled native programs.fish would double-write the
    # preinit for a per-user-only wrapper, so force it off and let my.fish own
    # /etc/fish (#69). `isDarwin` is evaluated first so this whole definition
    # short-circuits away on NixOS: there, gating programs.fish.enable on the
    # users.users scan inside `allFish` forms an infinite recursion (man-db's
    # completion cache, which contributes to users.users, reads
    # programs.fish.enable). On NixOS nothing enables native fish, so no
    # override is needed.
    (mkIf (isDarwin && allFish != []) {
      programs.fish.enable = mkForce false;
    })
  ];
}
