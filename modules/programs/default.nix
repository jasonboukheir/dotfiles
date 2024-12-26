{ ... }:
{
  imports = [
    ./devbox.nix
    ./direnv.nix
    ./ghostty.nix
    ./git.nix
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
