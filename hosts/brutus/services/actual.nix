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
        # discoveryURL = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
        # client_id._secret = config.age.secrets."actual/client_id".path;
        # client_secret._secret = config.age.secrets."actual/client_secret".path;
        # server_hostname = "https://${config.sunnycareboo.services.budget.domain}";
        # authMethod = "openId";
    };
  };
  age.secrets."actual/env".file = ../secrets/actual/env.age;
  sunnycareboo.services.budget = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };
  systemd.services.actual = lib.mkIf cfg.enable {
    environment = {
      ACTUAL_OPENID_DISCOVERY_URL = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
      ACTUAL_OPENID_SERVER_HOSTNAME = "https://${config.sunnycareboo.services.budget.domain}";
      ACTUAL_OPENID_AUTH_METHOD = "openid";
      ACTUAL_OPENID_ENFORCE = "true";
    };

    serviceConfig = {
      EnvironmentFile = config.age.secrets."actual/env".path;
    };
  };
}
