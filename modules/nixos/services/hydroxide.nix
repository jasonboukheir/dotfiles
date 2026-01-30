{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.hydroxide;
  scCfg = config.sunnycareboo;
in {
  options.services.hydroxide = {
    enable = lib.mkEnableOption "hydroxide ProtonMail bridge";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hydroxide";
      description = "Directory to store hydroxide data";
    };

    smtpPort = lib.mkOption {
      type = lib.types.port;
      default = 1025;
      description = "Internal SMTP port";
    };

    imapPort = lib.mkOption {
      type = lib.types.port;
      default = 1143;
      description = "Internal IMAP port";
    };

    publicSmtpPort = lib.mkOption {
      type = lib.types.port;
      default = 587;
      description = "Public SMTP port (with TLS via stunnel)";
    };

    publicImapPort = lib.mkOption {
      type = lib.types.port;
      default = 993;
      description = "Public IMAP port (with TLS via stunnel)";
    };

    certDomain = lib.mkOption {
      type = lib.types.str;
      default = scCfg.baseDomain;
      description = "Domain to use for TLS certificates";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create hydroxide user and group
    users.groups.hydroxide = {};
    users.users.hydroxide = {
      isSystemUser = true;
      group = "hydroxide";
      home = cfg.dataDir;
      createHome = true;
      description = "Hydroxide ProtonMail bridge user";
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 hydroxide hydroxide -"
    ];

    # Hydroxide service
    systemd.services.hydroxide = {
      description = "Hydroxide ProtonMail Bridge";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      serviceConfig = {
        Type = "simple";
        User = "hydroxide";
        Group = "hydroxide";
        WorkingDirectory = cfg.dataDir;

        # Run hydroxide serve on localhost only
        ExecStart = "${pkgs.hydroxide}/bin/hydroxide -smtp-host 127.0.0.1 -smtp-port ${toString cfg.smtpPort} -imap-host 127.0.0.1 -imap-port ${toString cfg.imapPort} -carddav-host 127.0.0.1 -carddav-port 1880 serve";

        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.dataDir];
      };
    };

    # Open firewall for public ports
    networking.firewall.allowedTCPPorts = [
      cfg.publicSmtpPort
      cfg.publicImapPort
    ];

    # Create stunnel user and group
    users.groups.stunnel = {};
    users.users.stunnel = {
      isSystemUser = true;
      group = "stunnel";
      extraGroups = ["acme"];
    };

    # stunnel for TLS termination
    services.stunnel = {
      enable = true;
      servers = {
        smtp = {
          accept = "0.0.0.0:${toString cfg.publicSmtpPort}";
          connect = "127.0.0.1:${toString cfg.smtpPort}";
          cert = "${config.security.acme.certs.${cfg.certDomain}.directory}/fullchain.pem";
          key = "${config.security.acme.certs.${cfg.certDomain}.directory}/key.pem";
          sslVersion = "TLSv1.2";
        };
        imap = {
          accept = "0.0.0.0:${toString cfg.publicImapPort}";
          connect = "127.0.0.1:${toString cfg.imapPort}";
          cert = "${config.security.acme.certs.${cfg.certDomain}.directory}/fullchain.pem";
          key = "${config.security.acme.certs.${cfg.certDomain}.directory}/key.pem";
          sslVersion = "TLSv1.2";
        };
      };
    };

    # Reload stunnel when certificates renew
    security.acme.certs.${cfg.certDomain}.reloadServices = ["stunnel.service"];

    # Add hydroxide to system packages for CLI access
    environment.systemPackages = [pkgs.hydroxide];
  };
}
