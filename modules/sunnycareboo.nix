# modules/sunnycareboo-services.nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sunnycareboo;

  serviceModule = types.submodule ({name, ...}: {
    options = {
      enable = mkEnableOption "this service";

      isExternal = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this is an external service";
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
    enable = mkEnableOption "Sunnycareboo service management";

    baseDomain = mkOption {
      type = types.str;
      default = "sunnycareboo.com";
      description = "Base domain for all services";
    };

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
    # Enable nginx if any services are enabled
    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts = mkMerge [
        # Services that we manage the virtualHost for
        (listToAttrs (mapAttrsToList (
            name: svcCfg: let
              domain = svcCfg.domain;

              # Base listeners (80 and 443)
              baseListen = [
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

              # Extra listeners for external services (8080 and 8443)
              extraListen =
                if svcCfg.isExternal
                then [
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
                ]
                else [];

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
            in
              nameValuePair domain {
                inherit (svcCfg) extraConfig;
                forceSSL = true;
                useACMEHost = cfg.baseDomain;
                listen = baseListen ++ extraListen;
                locations = allLocations;
              }
          ) (filterAttrs (
              name: svcCfg:
                svcCfg.enable
            )
            cfg.services)))
         {
           "_" = {
             serverName = "_";
             default = true;
             listen = [
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
             locations."/".return = "404";
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
        extraDomainNames = map (svc: svc.domain) (attrValues (filterAttrs (_: svc: svc.enable) cfg.services));
        email = "postmaster@${cfg.baseDomain}";
        dnsProvider = "cloudflare";
        credentialFiles = {
          "CF_DNS_API_TOKEN_FILE" = config.age.secrets."cloudflare/token".path;
          "CF_ZONE_API_TOKEN_FILE" = config.age.secrets."cloudflare/token".path;
        };
      };
    };

    users.users.nginx.extraGroups = lib.optionals cfg.enable ["acme"];
  };
}
