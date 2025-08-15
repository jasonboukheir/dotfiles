{...}: {
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
