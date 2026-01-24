{
  config,
  lib,
  ...
}: let
  cfg = config.services.mealie;
in {
  services.mealie = {
    enable = true;
    port = 9000;
    settings = {
      "OIDC_AUTH_ENABLED" = "True";
      "OIDC_SIGNUP_ENABLED" = "True";
      "OIDC_CONFIGURATION_URL" = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
      "OIDC_CLIENT_ID" = "32cb542a-a0b1-4278-8cfa-0dd5d9a2020d";
      "OIDC_ADMIN_GROUP" = "admin";
      "OIDC_PROVIDER_NAME" = "Pocket ID";

      "OPENAI_BASE_URL" = "https://${config.sunnycareboo.services.litellm.domain}";
      "OPENAI_MODEL" = "xai/grok-4-fast-non-reasoning";
    };
    database.createLocally = true;
    extraOptions = [];
    credentialsFile = config.age.secrets."mealie/env".path;
    listenAddress = "0.0.0.0";
  };

  age.secrets."mealie/env" = lib.mkIf cfg.enable {
    file = ../secrets/mealie/env.age;
  };

  sunnycareboo.services.meals = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.port}";
  };
}
