{
  config,
  lib,
  pkgs,
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

      noCache = mkOption {
        type = types.bool;
        default = true;
        description = "Add Cache-Control: no-cache to force browsers to revalidate on every request";
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

  config = mkIf cfg.enable (let
    hasExternal = any (svc: svc.enable && svc.isExternal) (attrValues cfg.services);
    hasNoCache = any (svc: svc.enable && svc.noCache) (attrValues cfg.services);
    nginxLogDir = "/var/log/nginx";
  in {
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
      commonHttpConfig =
        optionalString hasExternal ''
          map $server_port $external_limit_key {
            8443  $binary_remote_addr;
            8080  $binary_remote_addr;
            default "";
          }
          limit_req_zone $external_limit_key zone=external:10m rate=10r/s;

          map "$server_port:$ssl_client_verify" $mtls_reject {
            "~^8443:SUCCESS$"  0;
            "~^8443:"          1;
            default            0;
          }

          access_log ${nginxLogDir}/access.log;
          error_log ${nginxLogDir}/error.log warn;
        ''
        + optionalString hasNoCache ''
          map $upstream_http_cache_control $no_cache_cc_override {
            ""                    "no-cache";
            "~no-store"           $upstream_http_cache_control;
            "~no-cache"           $upstream_http_cache_control;
            "~must-revalidate"    $upstream_http_cache_control;
            default               "no-cache";
          }

          map $upstream_http_content_type $no_cache_override {
            ~image/                    $upstream_http_cache_control;
            ~video/                    $upstream_http_cache_control;
            ~audio/                    $upstream_http_cache_control;
            ~font/                     $upstream_http_cache_control;
            ~application/octet-stream  $upstream_http_cache_control;
            default                    $no_cache_cc_override;
          }
        '';

      virtualHosts = mkMerge [
        (listToAttrs (mapAttrsToList (
            name: svcCfg: let
              domain = svcCfg.domain;

              noCacheConfig = optionalString svcCfg.noCache ''
                proxy_hide_header Cache-Control;
                add_header Cache-Control $no_cache_override always;
              '';

              allLocations =
                optionalAttrs (svcCfg.proxyPass != null) {
                  "/" = {
                    proxyPass = svcCfg.proxyPass;
                    proxyWebsockets = svcCfg.proxyWebsockets;
                    extraConfig = noCacheConfig;
                  };
                }
                // (mapAttrs (path: locCfg: {
                    proxyPass = locCfg.proxyPass;
                    proxyWebsockets = locCfg.proxyWebsockets;
                    extraConfig = concatStringsSep "\n" (filter (s: s != "") [
                      locCfg.extraConfig
                      noCacheConfig
                    ]);
                  })
                  svcCfg.locations);
            in
              nameValuePair domain {
                forceSSL = true;
                useACMEHost = cfg.baseDomain;
                locations = allLocations;
                listen =
                  if svcCfg.isExternal
                  then internalHttpListeners ++ externalHttpListeners
                  else internalHttpListeners;
                extraConfig =
                  svcCfg.extraConfig
                  + optionalString svcCfg.isExternal ''
                    limit_req zone=external burst=20 nodelay;
                    limit_req_status 429;
                  ''
                  + optionalString svcCfg.mtls.enable ''
                    ssl_verify_client optional;
                    ssl_client_certificate ${cfg.mtls.caCertFile};
                    if ($mtls_reject) {
                      return 403;
                    }
                  '';
              }
          ) (filterAttrs (
              name: svcCfg:
                svcCfg.enable
            )
            cfg.services)))
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
      certs."${cfg.baseDomain}" = {
        domain = cfg.baseDomain;
        extraDomainNames = map (svc: svc.domain) (attrValues (filterAttrs (_: svc: svc.enable) cfg.services));
        email = "postmaster@${cfg.baseDomain}";
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
        nginx-limit-req = ''
          enabled  = true
          filter   = nginx-limit-req
          logpath  = ${nginxLogDir}/error.log
          maxretry = 10
          findtime = 60
          bantime  = 3600
        '';
      };
    };
  });
}
