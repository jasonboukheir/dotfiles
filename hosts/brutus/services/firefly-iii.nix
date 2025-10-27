{
  config,
  lib,
  ...
}: let
  cfg = config.services.firefly-iii;
  host = "budget.sunnycareboo.com";
  importerCfg = config.services.firefly-iii-data-importer;
  importerHost = "importer.budget.sunnycareboo.com";
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

  services.firefly-iii-data-importer = lib.mkIf cfg.enable {
    enable = true;
    enableNginx = true;
    virtualHost = importerHost;
    settings = {
      FIREFLY_III_URL = "https://${host}";
      FIREFLY_III_ACCESS_TOKEN_FILE = "/var/lib/secrets/firefly-iii-data-importer.pat";
    };
  };

  services.nginx.virtualHosts."${host}" = lib.mkIf (cfg.enable && cfg.enableNginx) {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
  };

  services.nginx.virtualHosts."${importerHost}" = lib.mkIf (importerCfg.enable && importerCfg.enableNginx) {
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
