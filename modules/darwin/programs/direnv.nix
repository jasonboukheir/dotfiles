{...}: {
  # System-level on darwin too; mirrors modules/nixos/programs/direnv.nix so
  # direnv + nix-direnv (and its shell hooks) are present on every host with a
  # system layer, not just NixOS.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
