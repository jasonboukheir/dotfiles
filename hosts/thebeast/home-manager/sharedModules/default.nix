{inputs, ...}: {
  home-manager.sharedModules = [
    inputs.nvf-nixos-unstable.homeManagerModules.default
    inputs.helium-flake.homeModules.default
  ];
}
