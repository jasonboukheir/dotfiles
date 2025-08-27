{...}: {
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [53 80 443];
    allowedUDPPorts = [53];
  };
  networking.networkmanager.enable = true;
  networking.hostName = "brutus"; # Define your hostname.
}
