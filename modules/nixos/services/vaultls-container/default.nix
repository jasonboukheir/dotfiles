{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vaultls-container;
  oidcCfg = cfg.oidc;
  stateDir = "/var/lib/vaultls";
  generatedApiSecretFile = "${stateDir}/api-secret";
  generatedDatabaseSecretFile = "${stateDir}/db-secret";
  apiSecretFile =
    if cfg.apiSecretFile != null
    then cfg.apiSecretFile
    else generatedApiSecretFile;
  databaseSecretFile =
    if cfg.databaseSecretFile != null
    then cfg.databaseSecretFile
    else generatedDatabaseSecretFile;
in {
  options.services.vaultls-container = {
    enable = lib.mkEnableOption "VaulTLS container";

    url = lib.mkOption {
      type = lib.types.str;
      description = ''
        Public URL where VaulTLS will be accessible.
        Used to set VAULTLS_URL and construct the OIDC callback URL.
      '';
      example = "https://vaultls.example.com/";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5173;
      description = "Port to bind the container's web interface (port 80) to on the host.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "vaultls";
      description = ''
        The volume to persist VaulTLS data.
        Can be a named volume (e.g., "vaultls") or a host path (e.g., "/var/lib/vaultls").
      '';
    };

    apiSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the API secret (VAULTLS_API_SECRET).
        The secret should be a 256-bit base64 encoded string.
        If not provided, a secret will be auto-generated in ${stateDir}/api-secret.
      '';
    };

    databaseSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the secret used to encrypt the database (VAULTLS_DB_SECRET). If not provided, a secret will be auto-generated in ${stateDir}/db-secret.";
    };

    logLevel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Set the log level for VaulTLS. If not set, VaulTLS will use its default. For example: trace, debug, info, warn, error.";
      example = "info";
    };

    oidc = {
      enable = lib.mkEnableOption "OIDC authentication";

      authUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Base URL of the OIDC provider (VAULTLS_OIDC_AUTH_URL).";
        example = "https://auth.example.com";
      };

      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OIDC client ID (VAULTLS_OIDC_ID).";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing the OIDC client secret (VAULTLS_OIDC_SECRET).";
      };
    };

    ca = {
      outputFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to write the CA certificate for use by other services (e.g., nginx mTLS).
          When set, enables automatic CA cert fetching from VaulTLS API.
          The file will be created with a placeholder cert initially, then updated
          once VaulTLS is set up.
        '';
        example = "/var/lib/vaultls/ca-tls.cert";
      };

      syncInterval = lib.mkOption {
        type = lib.types.str;
        default = "hourly";
        description = "How often to sync the CA certificate from VaulTLS (systemd calendar format).";
      };

      reloadServices = lib.mkOption {
        type = with lib.types; listOf str;
        default = [];
        description = "List of systemd services to reload when the CA certificate changes.";
        example = lib.literalExpression ''[ "nginx.service" ]'';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.mkIf oidcCfg.enable {
        assertion = oidcCfg.authUrl != null && oidcCfg.clientId != null && oidcCfg.clientSecretFile != null;
        message = "If OIDC is enabled, services.vaultls-container.oidc.authUrl, .clientId, and .clientSecretFile must be set.";
      })
    ];

    virtualisation.oci-containers.containers.vaultls = {
      image = "ghcr.io/7ritn/vaultls:latest";
      ports = ["${toString cfg.port}:80"];
      volumes = ["${cfg.dataDir}:/app/data"];

      environment = lib.filterAttrs (_: v: v != null) ({
          VAULTLS_URL = cfg.url;
          VAULTLS_LOG_LEVEL = cfg.logLevel;
        }
        // (lib.mkIf oidcCfg.enable {
          VAULTLS_OIDC_AUTH_URL = oidcCfg.authUrl;
          VAULTLS_OIDC_CALLBACK_URL = "${cfg.url}/api/auth/oidc/callback";
          VAULTLS_OIDC_ID = oidcCfg.clientId;
        }));

      environmentFiles = lib.filterAttrs (_: v: v != null) {
        VAULTLS_API_SECRET = apiSecretFile;
        VAULTLS_DB_SECRET = databaseSecretFile;
        VAULTLS_OIDC_SECRET =
          if oidcCfg.enable
          then oidcCfg.clientSecretFile
          else null;
      };
    };

    systemd.services.vaultls-setup = lib.mkIf (cfg.apiSecretFile == null || cfg.databaseSecretFile == null) {
      description = "VaulTLS setup - generate secrets if missing";
      wantedBy = ["oci-container-vaultls.service"];
      before = ["oci-container-vaultls.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p ${stateDir}
        ${lib.optionalString (cfg.apiSecretFile == null) ''
          if [ ! -f ${generatedApiSecretFile} ]; then
            echo "Generating VaulTLS API secret..."
            ${pkgs.openssl}/bin/openssl rand -base64 32 > ${generatedApiSecretFile}
            chmod 600 ${generatedApiSecretFile}
          fi
        ''}
        ${lib.optionalString (cfg.databaseSecretFile == null) ''
          if [ ! -f ${generatedDatabaseSecretFile} ]; then
            echo "Generating VaulTLS database secret..."
            ${pkgs.openssl}/bin/openssl rand -base64 32 > ${generatedDatabaseSecretFile}
            chmod 600 ${generatedDatabaseSecretFile}
          fi
        ''}
      '';
    };

    # CA certificate management
    systemd.services.vaultls-ca-init = lib.mkIf (cfg.ca.outputFile != null) {
      description = "Initialize VaulTLS CA certificate placeholder";
      before = cfg.ca.reloadServices;
      wantedBy = cfg.ca.reloadServices;
      path = [pkgs.openssl];
      unitConfig.ConditionPathExists = "!${cfg.ca.outputFile}";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p $(dirname ${cfg.ca.outputFile})
        # Create a temporary self-signed CA cert as placeholder
        # This will be replaced by the real VaulTLS CA once it's set up
        openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
          -keyout /tmp/placeholder-ca.key -out ${cfg.ca.outputFile} \
          -days 1 -nodes -subj "/CN=VaulTLS Placeholder CA"
        rm /tmp/placeholder-ca.key
        chmod 644 ${cfg.ca.outputFile}
        echo "Created placeholder CA certificate"
      '';
    };

    systemd.services.vaultls-ca-sync = lib.mkIf (cfg.ca.outputFile != null) {
      description = "Sync VaulTLS CA certificate for mTLS";
      after = ["podman-vaultls.service"];
      requires = ["podman-vaultls.service"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.curl pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = let
        reloadCmds = lib.concatMapStringsSep "\n" (svc: "systemctl reload ${svc} || true") cfg.ca.reloadServices;
      in ''
        # Wait for VaulTLS to be ready
        for i in $(seq 1 30); do
          if curl -sf "http://localhost:${toString cfg.port}/api/certificates/ca/download" -o /tmp/ca-tls.cert.new 2>/dev/null; then
            break
          fi
          echo "Waiting for VaulTLS to be ready... ($i/30)"
          sleep 2
        done

        if [ ! -f /tmp/ca-tls.cert.new ]; then
          echo "VaulTLS not ready or not set up yet, skipping CA sync"
          exit 0
        fi

        mkdir -p $(dirname ${cfg.ca.outputFile})

        # Only update and reload services if the cert changed
        if [ ! -f ${cfg.ca.outputFile} ] || ! cmp -s /tmp/ca-tls.cert.new ${cfg.ca.outputFile}; then
          mv /tmp/ca-tls.cert.new ${cfg.ca.outputFile}
          chmod 644 ${cfg.ca.outputFile}
          echo "CA certificate updated, reloading services..."
          ${reloadCmds}
        else
          rm /tmp/ca-tls.cert.new
          echo "CA certificate unchanged"
        fi
      '';
    };

    systemd.timers.vaultls-ca-sync = lib.mkIf (cfg.ca.outputFile != null) {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.ca.syncInterval;
        Persistent = true;
      };
    };
  };
}
