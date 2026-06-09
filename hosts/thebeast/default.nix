{...}: {
  imports = [
    ./system
    ./session
    ./home-manager
    ./secrets
    ./boot.nix
    ./graphics.nix
    ./helium.nix
    ./nvf.nix
    ./packages.nix
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
