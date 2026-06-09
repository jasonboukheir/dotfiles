{...}: {
  imports = [
    ./home-manager
    ./programs
    ./system
    ./environment.nix
    ./nix.nix
    ./users.nix
    ../my/nix-darwin.nix
  ];
}
