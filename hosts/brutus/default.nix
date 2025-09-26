{...}: {
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./disko-configuration.nix
    ./hardware-configuration.nix
    ./nixarr.nix
    ./nixpkgs.nix
    ./networking
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
