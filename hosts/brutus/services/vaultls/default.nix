{config, lib, ...}: let
  cfg = config.services.vaultls-container;
  dataDir = "/var/lib/vaultls";
  caCertFile = "${dataDir}/ca-tls.cert";
  domain = config.sunnycareboo.services.vaultls.domain;
  oidcCfg = config.services.pocket-id.ensureClients.vaultls;
in {
  services.vaultls-container = {
    enable = true;
    url = "https://${domain}";
    inherit dataDir;

    ca = {
      outputFile = caCertFile;
      reloadServices = ["nginx.service"];
    };

    oidc = {
      enable = true;
      authUrl = "https://${config.sunnycareboo.services.id.domain}";
      clientId = oidcCfg.settings.id;
      clientSecretFile = oidcCfg.secretFile;
    };
  };

  sunnycareboo.mtls.caCertFile = caCertFile;

  sunnycareboo.services.vaultls = {
    enable = cfg.enable;
    proxyPass = "http://localhost:${toString cfg.port}";
  };

  services.pocket-id.ensureClients.vaultls = lib.mkIf cfg.enable {
    logo = ./vaultls.svg;
    dependentServices = ["podman-vaultls.service"];
    settings = {
      name = "VaulTLS";
      launchURL = "https://${domain}";
      callbackURLs = [
        "https://${domain}/api/auth/oidc/callback"
      ];
    };
  };
}
