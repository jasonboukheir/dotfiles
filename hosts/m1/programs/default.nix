{ ... }:
{
  imports = [
    # ./brave.nix # not working in darwin yet...
    ./unity-hub.nix
    ./zed.nix
    ./vscode.nix
    ./proton-drive.nix
    ./iina.nix
  ];
}
