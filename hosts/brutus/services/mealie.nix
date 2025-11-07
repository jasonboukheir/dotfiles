{
  config,
  lib,
  ...
}: let
  cfg = config.services.mealie;
  domain = "meals.sunnycareboo.com";
in {
  services.mealie = {
    enable = true;
    port = 9000;
    settings = {
      "OIDC_AUTH_ENABLED" = "True";
      "OIDC_SIGNUP_ENABLED" = "True";
      "OIDC_CONFIGURATION_URL" = "https://pocket-id.sunnycareboo.com/.well-known/openid-configuration";
      "OIDC_CLIENT_ID" = "32cb542a-a0b1-4278-8cfa-0dd5d9a2020d";
      "OIDC_ADMIN_GROUP" = "admin";
      "OIDC_PROVIDER_NAME" = "Pocket ID";
    };
    database.createLocally = true;
    extraOptions = [];
    credentialsFile = config.age.secrets.mealieEnv.path;
    listenAddress = "0.0.0.0";
  };

  age.secrets.mealieEnv = lib.mkIf cfg.enable {
    file = ../secrets/mealie-env.age;
  };

  services.nginx.virtualHosts."${domain}" = lib.mkIf cfg.enable {
    forceSSL = true;
    enableACME = true;
    acmeRoot = null;
    locations."/" = {
      proxyWebsockets = true;
      proxyPass = "http://localhost:${toString cfg.port}";
    };
  };
}
