{inputs, ...}: {
  home-manager.sharedModules = [
    ./programs
    inputs.mac-app-util.homeManagerModules.default
  ];
}
