{...}: {
  imports = [
    ./jellyfin.nix
    ./nginx.nix
    ./openssh.nix
    ./pocket-id.nix
  ];
}
