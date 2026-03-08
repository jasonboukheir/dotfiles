{inputs, ...}: {
  home-manager.sharedModules = [
    inputs.nvf-nixos-unstable.homeManagerModules.default
  ];
}
