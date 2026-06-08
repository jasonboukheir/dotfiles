{inputs, ...}: {
  nixpkgs.overlays = [
    (import ./mkWrapped.nix)
    (import ./direnv.nix)
    (import ./fish.nix {inherit inputs;})
    (import ./pocket-id.nix)
    (import ./zmx.nix)
    (import ./speaches.nix)
    (import ./litellm.nix)
    (import ./waybar.nix)
  ];
}
