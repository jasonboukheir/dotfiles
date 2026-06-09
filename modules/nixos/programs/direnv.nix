{...}: {
  # Native module: enabling it sets up nix-direnv and emits the bash/zsh/fish
  # hooks (enable*Integration default on), replacing HM's programs.direnv.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
