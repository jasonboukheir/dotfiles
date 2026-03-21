{...}: {
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./cursors.nix
    ./ephemeral-secrets.nix
    ./users.nix
  ];
}
