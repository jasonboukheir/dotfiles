# nix-darwin entry point for my.*. nix-darwin supports users.users.<n>.packages
# (per-user profiles precede the system profile in PATH), so the system +
# per-user logic is shared with NixOS via ./system-scope.nix.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault filter attrValues head;

  # Every my.fish login-shell wrapper enabled across the per-user scopes.
  perUserFishPkgs =
    map (u: u.my.fish.finalPackage)
    (filter (u: u.my.fish.enable) (attrValues config.users.users));

  systemFishEnabled = config.my.fish.enable;
  anyFish = systemFishEnabled || perUserFishPkgs != [];

  # The single fish that becomes /run/current-system/sw/bin/fish. The system
  # wrapper wins when set; otherwise the first per-user wrapper (single-user
  # hosts have exactly one, so this is unambiguous in practice).
  fishPkg =
    if systemFishEnabled
    then config.my.fish.finalPackage
    else head perUserFishPkgs;
in {
  imports = [./system-scope.nix];

  # my.* program defs set no system state (see programs/CONTRACT.md), so the
  # darwin entry point owns fish's system integration. nix-darwin's programs.fish
  # generates /etc/fish/{nixos-env-preinit,config}.fish, which inject the nix
  # environment (PATH -> /run/current-system/sw/bin and the per-user profiles)
  # into every fish session. The my.fish wrapper is just a package; on its own it
  # never gets that wiring, so a my.fish login shell would launch with the bare
  # macOS PATH (no nix tools). Enabling programs.fish here restores it.
  #
  # TODO: piggybacking on programs.fish is a workaround; my.fish.enable should own
  # this env wiring itself (and unambiguously for multi-user / NixOS). Tracked at
  # https://github.com/jasonboukheir/dotfiles/issues/69
  config = mkIf anyFish {
    programs.fish = {
      enable = true;
      package = mkDefault fishPkg;
    };
    # Register the remaining per-user login-shell wrappers in /etc/shells;
    # modules/darwin/environment.nix already adds programs.fish.package (fishPkg),
    # so drop it here to avoid a duplicate entry.
    environment.shells = filter (p: p != fishPkg) perUserFishPkgs;
  };
}
