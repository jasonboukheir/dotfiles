{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./power
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
