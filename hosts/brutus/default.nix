{ ... }:
{
  imports = [
    ./home-manager
    ./programs
    ./security
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./users.nix
    ./../../modules
  ];
}
