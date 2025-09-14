{...}: {
  imports = [
    ./containers
    ./home-manager
    ./programs
    ./services
    ./systemd
    ./configuration.nix
    ./hardware-configuration.nix
    ./networking
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
