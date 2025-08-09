{ ... }:
{
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./users.nix
    ./../../modules
  ];
}
