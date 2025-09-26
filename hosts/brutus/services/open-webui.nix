{pkgs, ...}: {
  services.open-webui = {
    enable = false;
    port = 3100;
    package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies =
        oldAttrs.dependencies
        ++ [
          pkgs.python3Packages.itsdangerous
        ];
    });
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
    environmentFile = "/var/lib/secrets/openWebuiSecrets";
  };
  allowUnfreePackageNames = ["open-webui"];
}
