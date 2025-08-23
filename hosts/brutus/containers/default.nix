{...}: {
  imports = [
  # Doesn't work right now :(
    # ./bitcoin.nix
  ];
  programs.extra-container.enable = true;
}
