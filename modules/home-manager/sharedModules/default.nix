{inputs, ...}: {
  home-manager.sharedModules = [
    ./programs
    inputs.nixcord.homeModules.nixcord
    inputs.nvf.homeManagerModules.default
  ];
}
