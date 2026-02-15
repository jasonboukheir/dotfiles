{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./power
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./packages.nix
    ./networking
    ./virtualization.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/sunnycareboo
  ];
}
