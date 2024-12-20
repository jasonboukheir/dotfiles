{ ... }:
{
  imports = [
    ./devbox.nix
    ./direnv.nix
    ./git.nix
    ./kitty.nix
    ./starship.nix
    ./zsh.nix
    ./neovim.nix
    ./nix.nix
    ./ripgrep.nix
  ];
  home-manager.users.jasonbk = {
    programs.home-manager.enable = true;
  };
}
