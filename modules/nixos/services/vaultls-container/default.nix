{
  config,
  lib,
  ...
}: let
  cfg = config.services.vaultls-container;
  oidcCfg = cfg.oidc;
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
      type = lib.types.path;
      description = ''
        Path to a file containing the API secret (VAULTLS_API_SECRET).
        This is required.
        The secret should be a 256-bit base64 encoded string.
        You can generate one with: openssl rand -base64 32
      '';
    };

    databaseSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the secret used to encrypt the database (VAULTLS_DB_SECRET). If not provided, the database will not be encrypted.";
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

    after = lib.mkOption {
      type = with lib.types; listOf str;
      default = [];
      description = "A list of systemd units to start the VaulTLS container after.";
      example = lib.literalExpression ''[ "postgresql.service" ]'';
    };

    wants = lib.mkOption {
      type = with lib.types; listOf str;
      default = [];
      description = "A list of systemd units that the VaulTLS container wants.";
      example = lib.literalExpression ''[ "postgresql.service" ]'';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.apiSecretFile != null;
        message = "services.vaultls-container.apiSecretFile must be set.";
      }
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
        VAULTLS_API_SECRET = cfg.apiSecretFile;
        VAULTLS_DB_SECRET = cfg.databaseSecretFile;
        VAULTLS_OIDC_SECRET =
          if oidcCfg.enable
          then oidcCfg.clientSecretFile
          else null;
      };
    };

    systemd.services."oci-container-vaultls" = {
      after = cfg.after;
      wants = cfg.wants;
    };
  };
}
