{...}: {
  imports = [
    ./AdLib.nix
    ./darkmode.nix
    ./desktopservices.nix
    ./dock.nix
    ./finder.nix
    ./home-manager.nix
    ./mouse.nix
    ./nix-darwin-settings.nix
    ./NSGlobalDomain.nix
    ./screencapture.nix
    ./security.nix
    ./SoftwareUpdate.nix
    ./users.nix
    ./WindowManager.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
}
