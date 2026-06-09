{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.homelab;

  internalHttpListeners = [
    {
      addr = "0.0.0.0";
      port = 80;
      ssl = false;
    }
    {
      addr = "[::]";
      port = 80;
      ssl = false;
    }
    {
      addr = "0.0.0.0";
      port = 443;
      ssl = true;
    }
    {
      addr = "[::]";
      port = 443;
      ssl = true;
    }
  ];
  externalHttpListeners = [
    {
      addr = "0.0.0.0";
      port = 8080;
      ssl = false;
    }
    {
      addr = "[::]";
      port = 8080;
      ssl = false;
    }
    {
      addr = "0.0.0.0";
      port = 8443;
      ssl = true;
    }
    {
      addr = "[::]";
      port = 8443;
      ssl = true;
    }
  ];

  serviceModule = types.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "this service";

      isExternal = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is an external service";
      };

      registered = mkOption {
        type = types.bool;
        default = false;
        internal = true;
        description = ''
          Set by modules/homelab/registry.nix for every catalog entry. The
          drift assertion below uses it to fail an enabled service that has
          no registry entry (which would silently default its domain to
          internal).
        '';
      };

      mtls.enable = mkOption {
        type = types.bool;
        default = cfg.services.${name}.isExternal && cfg.mtls.caCertFile != null;
        defaultText = literalExpression "isExternal && config.homelab.mtls.caCertFile != null";
        description = "Enable mTLS client certificate verification for this service";
      };

      wildcard = mkOption {
        type = types.bool;
        default = false;
        description = ''
          When true, also serve a wildcard vhost at *.<domain> backed by the
          same proxyPass and add *.<domain> to the ACME cert SANs (DNS-01).
        '';
      };

      proxyPass = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Backend URL to proxy to (leave null if service configures nginx itself)";
        example = "http://localhost:3000";
      };

      proxyWebsockets = mkOption {
        type = types.bool;
        default = true;
        description = "Enable WebSocket proxying";
      };

      proxyReadTimeout = mkOption {
        type = types.str;
        default = "60s";
        description = ''
          nginx proxy_read_timeout for this service. Raise it for backends
          that hold a request open while doing slow work (e.g. *arr
          interactive searches that fan out across rate-limited indexers and
          exceed the 60s default).
        '';
        example = "600s";
      };

      locations = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            proxyPass = mkOption {
              type = types.nullOr types.str;
              default = null;
            };
            proxyWebsockets = mkOption {
              type = types.bool;
              default = true;
            };
            extraConfig = mkOption {
              type = types.lines;
              default = "";
            };
          };
        });
        default = {};
        description = "Additional location blocks";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra nginx server configuration";
      };

      # Computed/internal option - publicly accessible
      domain = mkOption {
        type = types.str;
        readOnly = true;
        default =
          if !cfg.services.${name}.isExternal
          then "${name}.internal.${cfg.domain}"
          else "${name}.${cfg.domain}";
        description = "Computed full domain name for this service";
      };
    };
  });
in {
  options.homelab = {
    services = mkOption {
      type = types.attrsOf serviceModule;
      default = {};
      description = ''
        Services to configure. The attribute name becomes the subdomain.
        Example: services.api creates api.sunnycareboo.com
                 services.admin with isExternal = false creates admin.internal.sunnycareboo.com
      '';
    };
  };

  config = mkIf cfg.enable (let
    hasExternal = any (svc: svc.enable && svc.isExternal) (attrValues cfg.services);
    nginxLogDir = "/var/log/nginx";
    unregistered = attrNames (filterAttrs (_: svc: svc.enable && !svc.registered) cfg.services);
  in {
    assertions = [
      {
        assertion = !(any (svc: svc.enable && svc.mtls.enable) (attrValues cfg.services)) || cfg.mtls.caCertFile != null;
        message = "homelab.mtls.caCertFile must be set when mTLS is enabled for any service";
      }
      {
        assertion = unregistered == [];
        message = "homelab services enabled without a modules/homelab/registry.nix entry (their domain would silently default to internal): ${concatStringsSep ", " unregistered}";
      }
    ];

    # Enable nginx if any services are enabled
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      commonHttpConfig = optionalString hasExternal ''
        map "$server_port:$ssl_client_verify" $mtls_reject {
          "~^8443:SUCCESS$"  0;
          "~^8443:"          1;
          default            0;
        }

        access_log ${nginxLogDir}/access.log;
        error_log ${nginxLogDir}/error.log warn;
      '';

      virtualHosts = mkMerge [
        (listToAttrs (concatMap (
            {
              name,
              value,
            }: let
              svcCfg = value;
              domain = svcCfg.domain;

              allLocations =
                optionalAttrs (svcCfg.proxyPass != null) {
                  "/" = {
                    proxyPass = svcCfg.proxyPass;
                    proxyWebsockets = svcCfg.proxyWebsockets;
                  };
                }
                // (mapAttrs (path: locCfg: {
                    proxyPass = locCfg.proxyPass;
                    proxyWebsockets = locCfg.proxyWebsockets;
                    extraConfig = locCfg.extraConfig;
                  })
                  svcCfg.locations);

              listenSpec =
                if svcCfg.isExternal
                then internalHttpListeners ++ externalHttpListeners
                else internalHttpListeners;

              mtlsExtra = optionalString svcCfg.mtls.enable ''
                ssl_verify_client optional;
                ssl_client_certificate ${cfg.mtls.caCertFile};
                if ($mtls_reject) {
                  return 403;
                }
              '';

              timeoutExtra = optionalString (svcCfg.proxyReadTimeout != "60s") ''
                proxy_read_timeout ${svcCfg.proxyReadTimeout};
                proxy_send_timeout ${svcCfg.proxyReadTimeout};
              '';

              primaryVhost = nameValuePair domain {
                forceSSL = true;
                useACMEHost = cfg.domain;
                locations = allLocations;
                listen = listenSpec;
                extraConfig = svcCfg.extraConfig + mtlsExtra + timeoutExtra;
              };

              wildcardVhost = nameValuePair "${domain}-wildcard" {
                serverName = "*.${domain}";
                forceSSL = true;
                useACMEHost = cfg.domain;
                locations = allLocations;
                listen = listenSpec;
                extraConfig = svcCfg.extraConfig + mtlsExtra + timeoutExtra;
              };
            in
              [primaryVhost] ++ optional svcCfg.wildcard wildcardVhost
          ) (mapAttrsToList nameValuePair (filterAttrs (
              name: svcCfg:
                svcCfg.enable
            )
            cfg.services))))
        # 2. Create a "catch-all" vhost to handle unknown domains/IPs
        {
          "_" = {
            default = true; # This adds the 'default_server' flag to the listen directive
            listen = internalHttpListeners ++ externalHttpListeners;
            rejectSSL = true;
            locations."/" = {
              return = "404";
            };
          };
        }
      ];
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals (any (svc: svc.enable) (attrValues cfg.services)) [80 443]
      ++ lib.optionals hasExternal [8080 8443];

    security.acme = {
      acceptTerms = true;
      certs."${cfg.domain}" = {
        domain = cfg.domain;
        extraDomainNames =
          (map (svc: svc.domain) (attrValues (filterAttrs (_: svc: svc.enable) cfg.services)))
          ++ (map (svc: "*.${svc.domain}") (attrValues (filterAttrs (_: svc: svc.enable && svc.wildcard) cfg.services)));
        email = "postmaster@${cfg.domain}";
      };
    };

    # When mTLS is configured with a runtime-provided CA cert, create a
    # placeholder so nginx can start before the real cert is exported.
    # The providing service should reload nginx once the real cert is ready.
    system.activationScripts.mtls-placeholder-cert = lib.mkIf (cfg.mtls.caCertFile != null) {
      text = ''
        cert="${cfg.mtls.caCertFile}"
        dir="$(dirname "$cert")"
        mkdir -p "$dir"
        if [ ! -f "$cert" ]; then
          ${lib.getExe' pkgs.openssl "openssl"} req -x509 -newkey ec \
            -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout /dev/null -out "$cert" \
            -days 1 -nodes -subj "/CN=placeholder" 2>/dev/null
        fi
      '';
    };

    users.users.nginx.extraGroups = ["acme"];

    environment.etc."fail2ban/filter.d/pocket-id.conf" = mkIf hasExternal {
      text = ''
        [Definition]
        journalmatch = _SYSTEMD_UNIT=pocket-id.service
        failregex    = token is invalid or expired.*"ip":"<HOST>"
      '';
    };

    services.fail2ban = mkIf hasExternal {
      enable = true;
      jails = {
        sshd = {
          enabled = true;
          settings.maxretry = 5;
        };
        nginx-botsearch = ''
          enabled  = true
          filter   = nginx-botsearch
          logpath  = ${nginxLogDir}/access.log
          maxretry = 2
          findtime = 60
        '';
        pocket-id = ''
          enabled  = true
          filter   = pocket-id
          backend  = systemd
          maxretry = 5
          findtime = 300
          bantime  = 3600
        '';
      };
    };
  });
}
