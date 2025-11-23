{...}: {
  imports = [
    ./home-manager
    ./networking
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./../../modules
    ./../../modules/nixos
  ];
}
