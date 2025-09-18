{...}: {
  imports = [
    ./containers
    ./home-manager
    ./programs
    ./services
    ./systemd
    ./configuration.nix
    ./disko-configuration.nix
    ./hardware-configuration.nix
    ./nixpkgs.nix
    ./networking
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
