{...}: {
  home-manager.sharedModules = [
    ./programs
    ./services
    ./stylix.nix
  ];
}
