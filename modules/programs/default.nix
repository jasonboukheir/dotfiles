{ ... }:
{
  imports = [
    ./1password.nix
    ./devbox.nix
    ./direnv.nix
    ./ghostty.nix
    ./git.nix
    ./neovim.nix
    ./nix.nix
    ./ripgrep.nix
    ./starship.nix
    ./telegram.nix
    ./zsh.nix
  ];
  home-manager.users.jasonbk = {
    programs.home-manager.enable = true;
  };
}
