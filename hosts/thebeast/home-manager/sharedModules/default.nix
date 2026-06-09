{inputs, ...}: {
  home-manager.sharedModules = [
    inputs.helium-flake.homeModules.default
  ];
}
