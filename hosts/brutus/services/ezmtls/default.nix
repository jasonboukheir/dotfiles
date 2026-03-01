{
  config,
  lib,
  ...
}: let
  cfg = config.services.ezmtls;
  oidcCfg = config.services.pocket-id.ensureClients.ezmtls;
  domain = config.sunnycareboo.services.certs.domain;
in {
  services.ezmtls = {
    enable = true;
    url = "https://${domain}";
    oidc = {
      issuer = "https://${config.sunnycareboo.services.id.domain}";
      clientId = oidcCfg.settings.id;
      clientSecretFile = oidcCfg.secretFile;
    };
    ensureCAs.mtls = {
      commonName = "Sunnycareboo mTLS CA";
    };
    initialAdmin.email = "jasonbk@sunnycareboo.com";
  };

  sunnycareboo.mtls.caCertFile = lib.mkIf cfg.enable cfg.ensureCAs.mtls.certFile;

  sunnycareboo.services.certs = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:4000";
  };

  services.pocket-id.ensureClients.ezmtls = lib.mkIf cfg.enable {
    dependentServices = ["ezmtls.service"];
    settings = {
      name = "ezmtls";
      launchURL = "https://${domain}";
      callbackURLs = [
        "https://${domain}/auth/oidc/callback"
      ];
    };
  };
}
