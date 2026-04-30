{
  config,
  lib,
  ...
}: let
  cfg = config.services.actual;
  domain = config.homelab.services.budget.domain;
  port = config.homelab.ports.values.actual;
  url = "https://${domain}";
  oidcCfg = config.services.pocket-id.ensureClients.actual;
in {
  homelab.ports.allocate.actual = lib.mkIf cfg.enable 5007;
  services.actual = {
    enable = true;
    settings = {
      port = port;
      openId = {
        discoveryURL = "https://${config.homelab.services.id.domain}/.well-known/openid-configuration";
        client_id = oidcCfg.settings.id;
        server_hostname = url;
      };
    };
  };
  homelab.services.budget = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://localhost:${toString port}";
  };

  services.pocket-id.ensureClients.actual = lib.mkIf cfg.enable {
    dependentServices = [config.systemd.services.actual.name];
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
