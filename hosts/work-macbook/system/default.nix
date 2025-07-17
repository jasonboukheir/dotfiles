{ ... }:
{
  imports = [
    ./dock.nix
    ./home-manager.nix
    ./ssh.nix
  ];
  system.primaryUser = "jasonbk";
}
