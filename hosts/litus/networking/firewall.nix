{...}: {
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };
}
