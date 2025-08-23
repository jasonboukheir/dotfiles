{...}: {
  imports = [
    ./containers
    ./home-manager
    ./programs
    ./services
    ./systemd
    ./configuration.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
