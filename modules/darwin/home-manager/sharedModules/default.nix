{inputs, ...}: {
  home-manager.sharedModules = [
    ./programs
    inputs.mac-app-util.homeManagerModules.default
    inputs.nvf-darwin.homeManagerModules.default
  ];
}
