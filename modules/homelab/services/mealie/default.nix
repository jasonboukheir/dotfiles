{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.meals;
  cfg = config.services.mealie;
  oidcCfg = config.services.pocket-id.ensureClients.mealie;
  domain = config.homelab.services.meals.domain;

  litellmCfg = config.services.litellm;
  litellmBase = "http://${litellmCfg.host}:${toString litellmCfg.port}";

  litellmModels = litellmCfg.settings.model_list or [];
  fastChatModel =
    (lib.findFirst
      (
        m:
          (m.model_info.mode or null)
          == "chat"
          && (m.litellm_params.extra_body.chat_template_kwargs.enable_thinking or true)
          == false
      )
      {model_name = "qwen3.6-fast";}
      litellmModels)
    .model_name;
in {
  config = lib.mkMerge [
    {
      homelab.services.meals = {
        proxyPass = "http://localhost:${toString cfg.port}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.mealie = 9000;

      services.mealie = {
        enable = true;
        port = config.homelab.ports.values.mealie;
        credentials = {
          OIDC_CLIENT_SECRET = oidcCfg.secretFile;
          OPENAI_API_KEY = config.age.secrets."mealie/openaiApiKey".path;
        };
        settings = {
          "OIDC_AUTH_ENABLED" = "True";
          "OIDC_SIGNUP_ENABLED" = "True";
          "OIDC_CONFIGURATION_URL" = "https://${config.homelab.services.id.domain}/.well-known/openid-configuration";
          "OIDC_CLIENT_ID" = oidcCfg.settings.id;
          "OIDC_ADMIN_GROUP" = "admin";
          "OIDC_PROVIDER_NAME" = "Pocket ID";

          "OPENAI_BASE_URL" = litellmBase;
          "OPENAI_MODEL" = fastChatModel;
        };
        database.createLocally = true;
        extraOptions = [];
        listenAddress = "0.0.0.0";
      };

      age.secrets."mealie/openaiApiKey".file = config.homelab.secretsDir + /mealie/openaiApiKey.age;

      services.pocket-id.ensureClients.mealie = {
        logo = ./mealie.svg;
        dependentServices = [config.systemd.services.mealie.name];
        settings = {
          name = "Mealie";
          launchURL = "https://${domain}";
          callbackURLs = [
            "https://${domain}/login"
            "https://${domain}/login?direct=1"
          ];
        };
      };
    })
  ];
}
