{ ... }:
{
  imports = [
    ./dock.nix
    ./home-manager.nix
    ./ipfs.nix
  ];
  system.primaryUser = "jasonbk";
}
