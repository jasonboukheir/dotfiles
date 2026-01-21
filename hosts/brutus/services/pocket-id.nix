{
  lib,
  config,
  ...
}: let
  port = 1411;
  domain = config.sunnycareboo.services.id.domain;
in {
  sunnycareboo.services.id = lib.mkIf config.services.pocket-id.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
    isExternal = true;
  };
  services.nginx.virtualHosts."${domain}" = {
    default = true;
  };
  age.secrets."pocket-id/encryptionKey" = {
    file = ../secrets/pocket-id/encryptionKey.age;
  };
  services.pocket-id = {
    enable = config.services.brutus.enable;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets."pocket-id/encryptionKey".path;
    };
    settings = {
      APP_URL = "https://${domain}";
      TRUST_PROXY = true;
      LOG_JSON = true;
      PORT = port;

      UI_CONFIG_DISABLED = false;
    };
  };
}
