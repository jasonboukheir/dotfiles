{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.certs;
  cfg = config.services.ezmtls;
  oidcCfg = config.services.pocket-id.ensureClients.ezmtls;
  smtpCfg = config.homelab.smtp;
  domain = config.homelab.services.certs.domain;
in {
  config = lib.mkMerge [
    {
      homelab.services.certs.proxyPass = "http://localhost:${toString cfg.port}";
    }
    (lib.mkIf homelabCfg.enable {
      services.ezmtls = {
        enable = true;
        url = "https://${domain}";
        oidc = {
          enable = true;
          issuer = "https://${config.homelab.services.id.domain}";
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

      homelab.mtls.caCertFile = cfg.ensureCAs.mtls.certFile;

      # Start after nginx so the OIDC endpoint is reachable, and reload
      # nginx once the real CA cert has been exported (replacing the placeholder).
      systemd.services.ezmtls = {
        after = ["nginx.service"];
        wants = ["nginx.service"];
        serviceConfig.ExecStartPost = "+${lib.getExe' pkgs.systemd "systemctl"} reload nginx.service";
      };

      services.pocket-id.ensureClients.ezmtls = {
        dependentServices = ["ezmtls.service"];
        settings = {
          name = "ezmtls";
          launchURL = "https://${domain}";
          callbackURLs = [
            "https://${domain}/auth/oidc/callback"
          ];
        };
      };
    })
  ];
}
