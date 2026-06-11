{...}: {
  imports = [
    ./networking
    ./services
    ./configuration.nix
    ./hardware-configuration.nix
    ./my.nix
    ./../../modules
    ./../../modules/nixos
    # The homelab settings layer only: domain, ports, and the service
    # registry (service names + their computed domains). The
    # implementations live under modules/homelab/services and are not
    # imported here, so litus references service domains without running
    # any service or carrying its flake inputs.
    ./../../modules/homelab
  ];
}
