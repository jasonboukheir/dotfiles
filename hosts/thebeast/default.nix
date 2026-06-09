{...}: {
  imports = [
    ./system
    ./session
    ./home-manager
    ./secrets
    ./boot.nix
    ./graphics.nix
    ./helium.nix
    ./my.nix
    ./packages.nix
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
