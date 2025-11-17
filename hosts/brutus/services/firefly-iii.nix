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
  age.secrets = lib.mkIf cfg.enable {
    firefly-iii-appkey = {
      file = ../secrets/firefly-iii-appkey.age;
      owner = cfg.user;
      group = cfg.group;
    };
  };
  services.firefly-iii = {
    enable = false;
    enableNginx = cfg.enable;
    virtualHost = host;
    settings = {
      APP_KEY_FILE = config.age.secrets.firefly-iii-appkey.path;
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
