{
  lib,
  config,
  ...
}: let
  cfg = config.services.headscale;
  domain = config.sunnycareboo.services.headscale.domain;
  baseDomain = config.sunnycareboo.baseDomain;
  internalDomain = "internal.${baseDomain}";
  magicDomain = "ts.${internalDomain}";
  issuerDomain = config.sunnycareboo.services.id.domain;
  port = 3400;
  oidcCfg = config.services.pocket-id.ensureClients.headscale;
in {
  services.headscale = {
    enable = true;
    port = port;
    settings = {
      tls_letsencrypt_listen = null;
      server_url = "https://${domain}";
      log.level = "verbose";
      dns = {
        override_local_dns = true;
        nameservers.global = ["100.64.0.1" "100.64.0.2"];
        base_domain = magicDomain;
        search_domains = [
          magicDomain
          baseDomain
          internalDomain
        ];
        extra_records = map (svc: {
          name = svc.domain;
          type = "A";
          value = "100.64.0.1";
        }) (lib.attrValues (lib.filterAttrs (_: svc: svc.enable) config.sunnycareboo.services));
      };
      oidc = {
        allowed_domains = [config.sunnycareboo.baseDomain];
        pkce.enabled = true;
        issuer = "https://${issuerDomain}";
        client_id = oidcCfg.settings.id;
      };
      prefixes.v4 = "100.64.0.0/10";
    };
  };

  sunnycareboo.services.headscale = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://localhost:${toString port}";
  };

  services.pocket-id.ensureClients.headscale = lib.mkIf cfg.enable {
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
}
