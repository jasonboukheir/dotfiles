{ ... }:
{
    programs.home-manager.enable = true;
    imports = [
        ./git.nix
        ./kitty.nix
        ./starship.nix
        ./zsh.nix
    ];
}
