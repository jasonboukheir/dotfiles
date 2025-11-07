{
  lib,
  config,
  ...
}: let
  cfg = config.services.nextcloud;
  domain = "cloud.sunnycareboo.com";
in {
  services.nextcloud = {
    enable = false;
    hostName = domain;
    https = true;
    database = {
      createLocally = true;
    };
    config = {
      dbtype = "pgsql";
    };
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };

  fileSystems."${cfg.datadir}" = lib.mkIf cfg.enable {
    depends = [
      "/"
      "/usb2"
    ];
    device = "/usb2/nextcloud";
    fsType = "none";
    options = ["bind"];
  };
}
