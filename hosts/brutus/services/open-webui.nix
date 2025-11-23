{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.open-webui;
  domain = "ai.sunnycareboo.com";
in {
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.postgres;
    });
    port = 3100;
    environment = {
      WEBUI_URL = "https://${domain}";
      ENV = "prod";

      # database settings
      DATABASE_URL = "postgresql://open-webui/open-webui?host=/run/postgresql";

      # privacy settings
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      ENABLE_VERSION_UPDATE_CHECK = "False";
      OFFLINE_MODE = "True";

      # pocket id oidc setup
      OPENID_PROVIDER_URL = "https://pocket-id.sunnycareboo.com/.well-known/openid-configuration";
      OAUTH_PROVIDER_NAME = "Pocket ID";
      OPENID_REDIRECT_URL = "https://${domain}/oauth/oidc/callback";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      ENABLE_OAUTH_SIGNUP = "True";
    };
    environmentFile = config.age.secrets.openWebuiEnv.path;
  };

  # Secrets
  age.secrets.openWebuiEnv = lib.mkIf cfg.enable {
    file = ../secrets/openWebui-env.age;
  };

  # NGINX
  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyPass = "http://localhost:${toString cfg.port}";
      proxyWebsockets = true;
    };
  };

  # PostgreSQL
  services.postgresql = lib.mkIf cfg.enable {
    ensureUsers = [
      {
        name = "open-webui";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "open-webui"
    ];
  };
}
