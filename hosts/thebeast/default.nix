{...}: {
  imports = [
    ./home-manager
    ./configuration.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./jovian.nix
    ./nixpkgs.nix
    ./omarchy.nix
    ./stylix.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/omarchy
  ];
}
