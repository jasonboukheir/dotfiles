# nvf (neovim) as a standalone-built package on hosts with a system layer
# (NixOS + nix-darwin): installed via environment.systemPackages. nvf bakes the
# whole config into the wrapped neovim, so we build it with
# `lib.neovimConfiguration` rather than threading it through home-manager.
# Standalone home-manager hosts use ./home-manager.nix. Part of #43.
{
  config,
  lib,
  ...
}: {
  imports = [
    ./options.nix
    ./config.nix
  ];

  config = lib.mkIf config.programs.nvf.enable {
    environment.systemPackages = [config.programs.nvf.finalPackage];
  };
}
