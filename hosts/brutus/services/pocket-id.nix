{config, ...}: {
  age.secrets.pocket-id-env = {
    file = ../secrets/pocket-id-env.age;
  };
  services.pocket-id = {
    enable = true;
    environmentFile = config.age.secrets.pocket-id-env.path;
    settings = {
      "APP_URL" = "https://pocket-id.sunnycareboo.com";
      "TRUST_PROXY" = true;
      "LOG_JSON" = true;
    };
  };
}
