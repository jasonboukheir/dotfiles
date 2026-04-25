{...}: {
  imports = [
    ./dock.nix
    ./home-manager.nix
    ./launchd.nix
  ];
  system.primaryUser = "jasonbk";
}
