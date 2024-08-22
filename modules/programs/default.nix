{ ... }:
{
  imports = [
    ./git.nix
    ./kitty.nix
    ./starship.nix
    ./zsh.nix
    ./neovim.nix
  ];
  home-manager.users.jasonbk = {
    programs.home-manager.enable = true;
  };
}
