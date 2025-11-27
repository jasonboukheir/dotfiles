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
  age.secrets."pocket-id/env" = {
    file = ../secrets/pocket-id/env.age;
  };
  services.pocket-id = {
    enable = true;
    environmentFile = config.age.secrets."pocket-id/env".path;
    settings = {
      "APP_URL" = "https://${domain}";
      "TRUST_PROXY" = true;
      "LOG_JSON" = true;
      "PORT" = port;
    };
  };
}
