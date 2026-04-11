{...}: {
  nixpkgs.overlays = [
    (import ./direnv.nix)
    (import ./lidarr.nix)
    (import ./pocket-id.nix)
  ];
}
