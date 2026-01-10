{
  config,
  lib,
  ...
}: let
  cfg = config.services.blocky;
in {
  services.blocky = {
    enable = config.services.brutus.enable;
  };

  sunnycareboo.services.blocky = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.settings.ports.http}";
  };

  networking.firewall = lib.mkIf cfg.enable {
    enable = true;
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };
}
