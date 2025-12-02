{...}: {
  imports = [
    ./home-manager
    ./configuration.nix
    ./desktop.nix
    ./hardware-configuration.nix
    ./nixpkgs.nix
    ./nvidia.nix
    ./steam.nix
    ./../../modules
    ./../../modules/nixos
  ];
}
