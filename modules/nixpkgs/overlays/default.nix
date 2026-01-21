{...}: {
  nixpkgs.overlays = [
    (import ./lidarr.nix)
    (import ./pocket-id.nix)
  ];
}
