{inputs, ...}: {
  home-manager.sharedModules = [
    inputs.nvf-nixos.homeManagerModules.default
  ];
}
