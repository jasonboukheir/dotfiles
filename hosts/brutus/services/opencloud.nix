{
  lib,
  config,
  ...
}: let
  cfg = config.services.opencloud;
  domain = "cloud.sunnycareboo.com";
in {
  services.opencloud = {
    enable = true;
    url = "https://${domain}";
    address = "127.0.0.1";
    port = 9200;
    stateDir = "/var/lib/opencloud";

    settings = {};
    environment = {
      "OC_INSECURE" = "false";
      "INSECURE" = "false";
      "INITIAL_ADMIN_PASSWORD" = "password";
    };
    environmentFile = "/var/lib/secrets/opencloud.env";
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyPass = "http://localhost:${toString cfg.port}";
      proxyWebsockets = true;
    };
  };

  fileSystems."${cfg.stateDir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/usb2"
    ];
    device = "/usb2/opencloud";
    fsType = "none";
    options = ["bind"];
  };
}
