{...}: {
  imports = [
    ./firewall.nix
    ./hostName.nix
    ./nat.nix
    ./networkmanager.nix
    ./wireguard.nix
  ];
}
