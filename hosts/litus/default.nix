{...}: {
  imports = [
    ./home-manager
    ./networking
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./../../modules
    ./../../modules/nixos
    # TODO: make it s.t. importing homelab is safe to get
    # defined options.
    #    ./../../modules/homelab
  ];
}
