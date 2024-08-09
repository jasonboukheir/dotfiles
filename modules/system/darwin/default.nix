{ ... }:
{
    imports = [
        ./AdLib.nix
        ./darkmode.nix
        ./desktopservices.nix
        ./dock.nix
        ./finder.nix
        ./Safari.nix
        ./screencapture.nix
        ./SoftwareUpdate.nix
    ];

    nixpkgs.hostPlatform = "aarch64-darwin";
    security.pam.enableSudoTouchIdAuth = true;
}
