{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./services
    ./configuration.nix
    ./disko-configuration.nix
    ./hardware-configuration.nix
    ./networking
    ./virtualization.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/sunnycareboo.nix
  ];
}
