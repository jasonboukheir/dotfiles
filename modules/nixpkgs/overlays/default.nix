{inputs, ...}: {
  nixpkgs.overlays = [
    (import ./direnv.nix)
    (import ./fish.nix {inherit inputs;})
    (import ./lidarr.nix)
    (import ./pocket-id.nix)
    (import ./zmx.nix)
    (import ./speaches.nix)
    (import ./intel-vllm-image.nix)
    (import ./intel-llm-scaler-vllm-image.nix)
    (import ./vllm-xpu-int4-tq-image.nix)
    (import ./llamacpp-intel-arc-server.nix)
    (import ./whispercpp-intel-arc-server.nix)
  ];
}
