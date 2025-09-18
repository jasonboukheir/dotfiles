{...}: {
  imports = [
    ./firewall.nix
    ./hostId.nix
    ./hostName.nix
    ./nat.nix
    ./networkmanager.nix
    ./wireguard.nix
  ];
}
