{inputs, ...}: {
  nixpkgs.overlays = [
    (import ./direnv.nix)
    (import ./fish.nix {inherit inputs;})
    (import ./gmx.nix)
    (import ./lidarr.nix)
    (import ./pocket-id.nix)
    (import ./zmx.nix)
  ];
}
