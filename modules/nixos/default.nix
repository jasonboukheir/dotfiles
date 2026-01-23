{...}: {
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./ephemeral-secrets.nix
    ./stylix.nix
    ./users.nix
  ];
}
