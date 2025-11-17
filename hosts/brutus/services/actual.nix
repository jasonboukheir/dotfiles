{
  config,
  lib,
  ...
}: let
  cfg = config.services.actual;
  host = "budget.sunnycareboo.com";
  port = 5007;
in {
  services.actual = {
    enable = true;
    settings = {
      port = port;
    };
  };
  services.nginx.virtualHosts."${host}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyPass = "http://localhost:${toString port}";
      proxyWebsockets = true;
    };
  };
}
