{ ... }:
{
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./users.nix
    ./../../modules
  ];
}
