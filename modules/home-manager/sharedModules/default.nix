{ inputs, ... }:
{
  home-manager.sharedModules = [
    ./programs
    inputs.nvf.homeManagerModules.default
  ];
}
