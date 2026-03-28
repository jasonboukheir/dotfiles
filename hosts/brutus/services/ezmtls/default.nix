{
  config,
  lib,
  pkgs,
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
      enable = true;
      issuer = "https://${config.sunnycareboo.services.id.domain}";
      clientId = oidcCfg.settings.id;
      clientSecretFile = oidcCfg.secretFile;
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
    serviceConfig.ExecStartPost = let
      caCertFile = cfg.ensureCAs.mtls.certFile;
      waitAndReload = pkgs.writeShellScript "ezmtls-reload-nginx" ''
        timeout=60
        while [ "$timeout" -gt 0 ]; do
          if ${lib.getExe' pkgs.openssl "openssl"} x509 -in "${caCertFile}" -noout -subject 2>/dev/null | grep -qv "placeholder"; then
            ${lib.getExe' pkgs.systemd "systemctl"} reload nginx.service
            exit 0
          fi
          sleep 1
          timeout=$((timeout - 1))
        done
        echo "ezmtls: timed out waiting for real CA cert, reloading nginx anyway" >&2
        ${lib.getExe' pkgs.systemd "systemctl"} reload nginx.service
      '';
    in "+${waitAndReload}";
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
