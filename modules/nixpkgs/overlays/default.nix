{inputs, ...}: {
  nixpkgs.overlays = [
    (import ./direnv.nix)
    (import ./fish.nix {inherit inputs;})
    (import ./lidarr.nix)
    (import ./pocket-id.nix)
  ];
}
