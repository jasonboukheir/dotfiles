{
  config,
  lib,
  ...
}: let
  cfg = config.services.firefly-iii;
  host = "budget.sunnycareboo.com";
in {
  services.firefly-iii = {
    enable = true;
    enableNginx = true;
    virtualHost = host;
    settings = {
      APP_KEY_FILE = "/var/lib/secrets/firefly-iii.appkey";
      DB_CONNECTION = "pgsql";
      DB_USERNAME = cfg.user;
      DB_DATABASE = cfg.user;
    };
  };

  services.nginx.virtualHosts."${host}" = lib.mkIf (cfg.enable && cfg.enableNginx) {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };

  services.postgresql = lib.mkIf (cfg.enable && cfg.settings.DB_CONNECTION == "pgsql") {
    ensureUsers = [
      {
        name = cfg.settings.DB_USERNAME;
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      cfg.settings.DB_DATABASE
    ];
  };
}
