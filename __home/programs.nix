{ ... }:
{
  imports = [
    ./programs/1password.nix
    ./programs/git.nix
    ./programs/kitty.nix
    ./programs/starship.nix
    ./programs/vscode.nix
    ./programs/zed.nix
    ./programs/zsh.nix
  ];

  programs.home-manager.enable = true;
}