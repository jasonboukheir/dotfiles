{
  lib,
  config,
  ...
}: let
  homelabCfg = config.homelab.services.headscale;
  domain = config.homelab.services.headscale.domain;
  baseDomain = config.homelab.domain;
  internalDomain = "internal.${baseDomain}";
  magicDomain = "ts.${internalDomain}";
  issuerDomain = config.homelab.services.id.domain;
  port = config.homelab.ports.values.headscale;
  oidcCfg = config.services.pocket-id.ensureClients.headscale;
  brutusTailscaleIP = "100.64.0.2";
  litusTailscaleIP = "100.64.0.1";
in {
  config = lib.mkMerge [
    {
      homelab.services.headscale = {
        mtls.enable = false;
        isExternal = true;
        proxyPass = "http://localhost:${toString port}";
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.headscale = 3400;

      services.headscale = {
        enable = true;
        port = port;
        settings = {
          tls_letsencrypt_listen = null;
          server_url = "https://${domain}";
          log.level = "verbose";
          dns = {
            override_local_dns = true;
            nameservers.global = [brutusTailscaleIP litusTailscaleIP];
            base_domain = magicDomain;
            search_domains = [
              magicDomain
              baseDomain
              internalDomain
            ];
            extra_records = map (svc: {
              name = svc.domain;
              type = "A";
              value = brutusTailscaleIP;
            }) (lib.attrValues (lib.filterAttrs (_: svc: svc.enable) config.homelab.services));
          };
          oidc = {
            allowed_domains = [baseDomain];
            pkce.enabled = true;
            issuer = "https://${issuerDomain}";
            client_id = oidcCfg.settings.id;
          };
          prefixes.v4 = "100.64.0.0/10";
        };
      };

      # Start after nginx so the OIDC endpoint is reachable.
      systemd.services.headscale = {
        after = ["nginx.service"];
        wants = ["nginx.service"];
      };

      services.pocket-id.ensureClients.headscale = {
        logo = ./headscale.svg;
        dependentServices = [config.systemd.services.headscale.name];
        settings = {
          name = "Headscale";
          isPublic = true;
          launchURL = "https://${domain}";
          callbackURLs = [
            "https://${domain}/oidc/callback"
          ];
        };
      };
    })
  ];
}
