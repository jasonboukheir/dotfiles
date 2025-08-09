{ ... }:
{
  imports = [
    ./home-manager
    ./programs
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./../../modules
  ];
}
