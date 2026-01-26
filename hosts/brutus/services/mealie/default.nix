{
  config,
  lib,
  ...
}: let
  cfg = config.services.mealie;
  oidcCfg = config.services.pocket-id.ensureClients.mealie;
  domain = config.sunnycareboo.services.meals.domain;
in {
  services.mealie = {
    enable = true;
    port = 9000;
    credentials = {
      OIDC_CLIENT_SECRET = oidcCfg.secretFile;
      OPENAI_API_KEY = config.age.secrets."mealie/openaiApiKey".path;
    };
    settings = {
      "OIDC_AUTH_ENABLED" = "True";
      "OIDC_SIGNUP_ENABLED" = "True";
      "OIDC_CONFIGURATION_URL" = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
      "OIDC_CLIENT_ID" = oidcCfg.settings.id;
      "OIDC_ADMIN_GROUP" = "admin";
      "OIDC_PROVIDER_NAME" = "Pocket ID";

      "OPENAI_BASE_URL" = "https://${config.sunnycareboo.services.litellm.domain}";
      "OPENAI_MODEL" = "xai/grok-4-fast-non-reasoning";
    };
    database.createLocally = true;
    extraOptions = [];
    listenAddress = "0.0.0.0";
  };

  age.secrets."mealie/openaiApiKey" = lib.mkIf cfg.enable {
    file = ../../secrets/mealie/openaiApiKey.age;
  };

  sunnycareboo.services.meals = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.port}";
  };

  services.pocket-id.ensureClients.mealie = lib.mkIf cfg.enable {
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
}
