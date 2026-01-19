{...}: {
  nixpkgs.overlays = [
    (import ./lidarr.nix)
  ];
}
