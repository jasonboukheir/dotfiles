{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sunnycareboo;

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

      mtls.enable = mkOption {
        type = types.bool;
        default = cfg.services.${name}.isExternal && cfg.mtls.caCertFile != null;
        defaultText = literalExpression "isExternal && config.sunnycareboo.mtls.caCertFile != null";
        description = "Enable mTLS client certificate verification for this service";
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
          then "${name}.internal.${cfg.baseDomain}"
          else "${name}.${cfg.baseDomain}";
        description = "Computed full domain name for this service";
      };
    };
  });
in {
  options.sunnycareboo = {
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

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(any (svc: svc.enable && svc.mtls.enable) (attrValues cfg.services)) || cfg.mtls.caCertFile != null;
        message = "sunnycareboo.mtls.caCertFile must be set when mTLS is enabled for any service";
      }
    ];

    # Enable nginx if any services are enabled
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts = mkMerge [
        # Services that we manage the virtualHost for
        (listToAttrs (concatLists (mapAttrsToList (
            name: svcCfg: let
              domain = svcCfg.domain;

              # Build locations (only if proxyPass is set)
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

              # Base vhost config shared between internal and external
              baseVhostConfig = {
                inherit (svcCfg) extraConfig;
                forceSSL = true;
                useACMEHost = cfg.baseDomain;
                locations = allLocations;
              };

              # Internal vhost (ports 80/443) - no mTLS
              internalVhost = nameValuePair domain (baseVhostConfig // {
                listen = internalHttpListeners;
              });

              # External vhost (ports 8080/8443) - with mTLS if enabled
              externalVhost = nameValuePair "${domain}-external" (baseVhostConfig // {
                serverName = domain;
                listen = externalHttpListeners;
              }
              // optionalAttrs svcCfg.mtls.enable {
                extraConfig = svcCfg.extraConfig + ''
                  ssl_verify_client on;
                '';
                sslTrustedCertificate = cfg.mtls.caCertFile;
              });
            in
              # Internal services: just internal vhost
              # External services: internal vhost + external vhost (with mTLS)
              if svcCfg.isExternal
              then [internalVhost externalVhost]
              else [internalVhost]
          ) (filterAttrs (
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

    networking.firewall.allowedTCPPorts = let
      hasExternal = any (svc: svc.enable && svc.isExternal) (attrValues cfg.services);
    in
      lib.optionals (any (svc: svc.enable) (attrValues cfg.services)) [80 443]
      ++ lib.optionals hasExternal [8080 8443];

    security.acme = lib.mkIf cfg.enable {
      acceptTerms = true;
      certs."${cfg.baseDomain}" = {
        domain = cfg.baseDomain;
        extraDomainNames = map (svc: svc.domain) (attrValues (filterAttrs (_: svc: svc.enable) cfg.services));
        email = "postmaster@${cfg.baseDomain}";
      };
    };

    users.users.nginx.extraGroups = lib.optionals cfg.enable ["acme"];
  };
}
