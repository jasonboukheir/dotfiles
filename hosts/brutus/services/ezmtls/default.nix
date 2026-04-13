{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.ezmtls;
  oidcCfg = config.services.pocket-id.ensureClients.ezmtls;
  smtpCfg = config.sunnycareboo.smtp;
  domain = config.sunnycareboo.services.certs.domain;
in {
  services.ezmtls = {
    enable = true;
    url = "https://${domain}";
    oidc = {
      enable = true;
      issuer = "https://${config.sunnycareboo.services.id.domain}";
      clientId = oidcCfg.settings.id;
      clientSecretFile = oidcCfg.secretFile;
    };
    smtp = {
      host = smtpCfg.host;
      port = smtpCfg.port;
      from = smtpCfg.from;
      username = smtpCfg.username;
      passwordFile = smtpCfg.passwordFile;
    };
    ensureCAs.mtls = {
      commonName = "Sunnycareboo mTLS CA";
    };
    seedAccounts = [
      {
        name = "Jason Bou Kheir";
        email = "jasonbk@sunnycareboo.com";
        role = "admin";
      }
    ];
  };

  sunnycareboo.mtls.caCertFile = lib.mkIf cfg.enable cfg.ensureCAs.mtls.certFile;

  sunnycareboo.services.certs = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://localhost:${toString cfg.port}";
  };

  # Start after nginx so the OIDC endpoint is reachable, and reload
  # nginx once the real CA cert has been exported (replacing the placeholder).
  systemd.services.ezmtls = lib.mkIf cfg.enable {
    after = ["nginx.service"];
    wants = ["nginx.service"];
    serviceConfig.ExecStartPost = "+${lib.getExe' pkgs.systemd "systemctl"} reload nginx.service";
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
