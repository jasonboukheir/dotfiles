{...}: {
  imports = [
    ./home-manager
    ./configuration.nix
    ./desktop.nix
    ./hardware-configuration.nix
    ./nixpkgs.nix
    ./nvidia.nix
    ./omarchy.nix
    ./jovian.nix
    ./stylix.nix
    ./../../modules
    ./../../modules/nixos
  ];
}
