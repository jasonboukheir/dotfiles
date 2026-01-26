{
  config,
  lib,
  ...
}: let
  cfg = config.services.actual;
  domain = config.sunnycareboo.services.budget.domain;
  port = 5007;
  url = "https://${domain}";
  oidcCfg = config.services.pocket-id.ensureClients.actual;
in {
  services.actual = {
    enable = true;
    settings = {
      port = port;
      openId = {
        discoveryURL = "https://${config.sunnycareboo.services.id.domain}/.well-known/openid-configuration";
        client_id = oidcCfg.settings.id;
        server_hostname = url;
      };
    };
  };
  sunnycareboo.services.budget = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
  };

  services.pocket-id.ensureClients.actual = lib.mkIf cfg.enable {
    dependentServices = ["actual"];
    logo = ./actual-budget.svg;
    settings = {
      name = "Actual Budget";
      launchURL = url;
      isPublic = true;
      callbackURLs = [
        "${url}/openid/callback"
      ];
    };
  };
}
