{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./programs
    ./services
    ./configuration.nix
    ./disko-configuration.nix
    ./hardware-configuration.nix
    ./nixpkgs.nix
    ./networking
    ./sops.nix
    ./users.nix
    ./../../modules
  ];
}
