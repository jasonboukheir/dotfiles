{...}: {
  imports = [
    ./home-manager
    ./nixarr
    ./power
    ./services
    ./configuration.nix
    ./graphics.nix
    ./hardware-configuration.nix
    ./packages.nix
    ./stylix.nix
    ./networking
    ./virtualization.nix
    ./../../modules
    ./../../modules/nixos
    ./../../modules/homelab
    # brutus is the host that actually runs the homelab services, so it
    # imports the implementations (which reference flake-input options
    # like services.ezmtls) on top of the shared settings layer above.
    ./../../modules/homelab/services
  ];
}
