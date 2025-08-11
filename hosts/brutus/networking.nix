{ ... }:
{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };
  networking.networkmanager.enable = true;
  networking.hostName = "brutus"; # Define your hostname.
}
