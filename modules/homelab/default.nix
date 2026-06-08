{...}: {
  # Settings layer: homelab options, the service framework
  # (nginx/ACME/mtls/port allocation), well-known publishing, and the
  # shared service registry (which services exist + their domains). Every
  # host imports this to reference homelab settings without running any
  # service. The implementations live under ./services and are imported
  # only by the host that hosts them, alongside the backing flake inputs.
  imports = [
    ./settings.nix
    ./ports.nix
    ./services.nix
    ./wellKnown.nix
    ./registry.nix
  ];
}
