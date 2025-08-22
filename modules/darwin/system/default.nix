{...}: {
  imports = [
    ./AdLib.nix
    ./darkmode.nix
    ./desktopservices.nix
    ./dock.nix
    ./finder.nix
    ./mouse.nix
    ./NSGlobalDomain.nix
    ./screencapture.nix
    ./security.nix
    ./SoftwareUpdate.nix
    ./WindowManager.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
}
