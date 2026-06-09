{...}: {
  # System-level on every host with a system layer. modules/programs is shared
  # by the NixOS and darwin system configs (not the standalone home-manager
  # hosts), and both platforms expose the same programs.direnv interface, so a
  # single module covers them — like fd.nix/rg.nix. The native module enables
  # nix-direnv and emits the bash/zsh/fish hooks.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
