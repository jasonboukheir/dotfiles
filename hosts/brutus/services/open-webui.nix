{config, ...}: {
  age.secrets.openWebuiEnv = {
    file = ../secrets/openWebui-env.age;
  };
  services.open-webui = {
    enable = true;
    port = 3100;
    environment = {
      WEBUI_URL = "https://ai.sunnycareboo.com";

      # privacy settings
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";

      # pocket id oidc setup
      OPENID_PROVIDER_URL = "https://pocket-id.sunnycareboo.com/.well-known/openid-configuration";
      OAUTH_PROVIDER_NAME = "Pocket ID";
      OPENID_REDIRECT_URL = "https://ai.sunnycareboo.com/oauth/oidc/callback";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
      ENABLE_OAUTH_SIGNUP = "True";
    };
    environmentFile = config.age.secrets.openWebuiEnv.path;
  };
  allowUnfreePackageNames = ["open-webui"];
}
