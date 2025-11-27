{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.open-webui;
  domain = config.sunnycareboo.services.ai.domain;
  port = 3100;
in {
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.postgres;
    });
    port = port;
    environment = lib.mkMerge ([
        {
          ENABLE_PERSISTENT_CONFIG = "False";
          WEBUI_URL = "https://${domain}";
          ENV = "prod";
          CORS_ALLOW_ORIGIN = "https://${domain}";

          # database settings
          DATABASE_URL = "postgresql://open-webui/open-webui?host=/run/postgresql";

          # privacy settings
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";
          ENABLE_VERSION_UPDATE_CHECK = "False";
          OFFLINE_MODE = "True";

          # pocket id oidc setup
          OPENID_PROVIDER_URL = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
          OAUTH_PROVIDER_NAME = "Pocket ID";
          OPENID_REDIRECT_URL = "https://${domain}/oauth/oidc/callback";
          OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
          ENABLE_OAUTH_SIGNUP = "True";

          # search settings
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://${config.sunnycareboo.services.search.domain}/search?q=<query>"
        }
      ]
      ++ (lib.optional config.services.litellm-container.enable {
        # OPENAI API
        OPENAI_API_BASE_URL = "https://${config.sunnycareboo.services.litellm.domain}";
      }));
    environmentFile = config.age.secrets."open-webui/env".path;
  };

  # Secrets
  age.secrets."open-webui/env" = lib.mkIf cfg.enable {
    file = ../secrets/open-webui/env.age;
  };

  # NGINX
  sunnycareboo.services.ai = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.port}";
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
