{
  config,
  lib,
  ...
}: let
  cfg = config.services.actual;
  port = 5007;
in {
  services.actual = {
    enable = true;
    settings = {
      port = port;
      openId = {
        discoveryURL = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
        client_id._secret = config.age.secrets."actual/client_id".path;
        client_secret._secret = config.age.secrets."actual/client_secret".path;
        server_hostname = "https://${config.sunnycareboo.services.budget.domain}";
        authMethod = "openId";
      };
    };
  };
  age.secrets."actual/client_id".file = ../secrets/actual/client_id.age;
  age.secrets."actual/client_secret".file = ../secrets/actual/client_secret.age;
  sunnycareboo.services.budget = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };
}
