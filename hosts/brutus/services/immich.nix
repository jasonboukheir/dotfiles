{
  config,
  lib,
  ...
}: let
  cfg = config.services.immich;
  domain = "photos.sunnycareboo.com";
in {
  services.immich = {
    enable = true;
    port = 2283;
    database = {
      user = "immich";
      port = 5432;
      name = "immich";
      createDB = true;
    };
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyPass = "http://localhost:${toString cfg.port}";
      proxyWebsockets = true;
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 5000M;
        proxy_read_timeout   600s;
        proxy_send_timeout   600s;
        send_timeout         600s;
      '';
    };
  };

  fileSystems."${cfg.mediaLocation}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/usb2"
    ];
    device = "usb2/immich";
    fsType = "none";
    options = ["bind"];
  };
}
