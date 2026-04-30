{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.budget;
  domain = config.homelab.services.budget.domain;
  port = config.homelab.ports.values.actual;
  url = "https://${domain}";
  oidcCfg = config.services.pocket-id.ensureClients.actual;
in {
  config = lib.mkMerge [
    {
      homelab.services.budget = {
        isExternal = true;
        proxyPass = "http://localhost:${toString port}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.actual = 5007;
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

      services.pocket-id.ensureClients.actual = {
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
    })
  ];
}
