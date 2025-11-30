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
        extra_records = [
          {
            name = "sunnycareboo.com";
            type = "A";
            value = "100.64.0.1";
          }
        ];
      };
      oidc = {
        allowed_domains = [config.sunnycareboo.baseDomain];
        pkce.enabled = true;
        issuer = "https://${issuerDomain}";
        client_id = "42a92e0e-0cb3-4545-bcae-a77115d8db5b";
        client_secret_path = config.age.secrets."headscale/clientSecret".path;
      };
      prefixes.v4 = "100.64.0.0/10";
    };
  };
  age.secrets."headscale/clientSecret" = {
    file = ../secrets/headscale/clientSecret.age;
    owner = cfg.user;
    group = cfg.group;
  };
  sunnycareboo.services.headscale = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://localhost:${toString port}";
  };
}
