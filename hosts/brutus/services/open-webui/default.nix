{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.open-webui;
  oidcCfg = config.services.pocket-id.ensureClients.open-webui;
  domain = config.sunnycareboo.services.ai.domain;
  port = 3100;
in {
  allowUnfreePackageNames = lib.optionals cfg.enable ["open-webui"];
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
          OAUTH_CLIENT_ID = oidcCfg.settings.id;
          OAUTH_CODE_CHALLENGE_METHOD = "S256";
          OAUTH_PROVIDER_NAME = "Pocket ID";
          OPENID_REDIRECT_URL = "https://${domain}/oauth/oidc/callback";
          OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
          ENABLE_OAUTH_SIGNUP = "True";

          # search settings
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://${config.sunnycareboo.services.search.domain}/search?q=<query>";
        }
      ]
      ++ (lib.optional config.services.litellm-container.enable {
        # OPENAI API
        OPENAI_API_BASE_URL = "https://${config.sunnycareboo.services.litellm.domain}";
      }));
    credentials = {
      "OPENAI_API_KEY" = config.age.secrets."open-webui/openaiApiKey".path;
      "WEBUI_SECRET_KEY" = config.age.secrets."open-webui/webuiSecretKey".path;
    };
  };

  services.pocket-id.ensureClients.open-webui = lib.mkIf cfg.enable {
    logo = ./open-webui-light.svg;
    darkLogo = ./open-webui-dark.svg;
    dependentServices = [config.systemd.services.open-webui.name];
    settings = {
      name = "Open WebUI";
      isPublic = true;
      launchURL = "https://${domain}";
      callbackURLs = [
        cfg.environment."OPENID_REDIRECT_URL"
      ];
    };
  };

  age.secrets = lib.mkIf cfg.enable {
    "open-webui/openaiApiKey".file = ../../secrets/open-webui/openaiApiKey.age;
    "open-webui/webuiSecretKey".file = ../../secrets/open-webui/webuiSecretKey.age;
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
