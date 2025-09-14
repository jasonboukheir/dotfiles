{...}: {
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [53 80 443];
    allowedUDPPorts = [53 51820];
  };
}
