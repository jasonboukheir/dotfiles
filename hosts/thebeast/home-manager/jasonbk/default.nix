{inputs, ...}: {
  home.stateVersion = "25.11";
  imports = [
    inputs.omarchy-nix.homeManagerModules.default
    ./programs
  ];
}
