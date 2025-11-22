{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./programs
    ./services
    ./configuration.nix
    ./disko-configuration.nix
    ./hardware-configuration.nix
    ./networking
    ./users.nix
    ./virtualization.nix
    ./../../modules
  ];
}
