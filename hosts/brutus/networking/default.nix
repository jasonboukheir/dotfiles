{...}: {
  imports = [
    ./hostId.nix
    ./hostName.nix
    ./initrd-ssh.nix
    ./networkmanager.nix
  ];
}
