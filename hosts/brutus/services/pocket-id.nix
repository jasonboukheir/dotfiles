{config, ...}: {
  services.pocket-id = {
    enable = true;
    environmentFile = config.sops.secrets."pocket-id/env".path;
    settings = {
      "APP_URL" = "https://pocket-id.sunnycareboo.com";
      "TRUST_PROXY" = true;
      "LOG_JSON" = true;
    };
  };
}
