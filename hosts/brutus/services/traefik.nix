{config, ...}: {
  services.traefik = {
    enable = true;
    environmentFiles = [
      config.sops.secrets."traefik/env".path
    ];
    staticConfigOptions = {
      experimental = {
        plugins = {
          "traefik-oidc-auth" = {
            moduleName = "github.com/sevensolutions/traefik-oidc-auth";
            version = "v0.14.0";
          };
        };
      };

      entryPoints = {
        web = {
          address = ":80";
          asDefault = true;
          http.redirections.entrypoint = {
            to = "websecure";
            scheme = "https";
          };
        };
        websecure = {
          address = ":443";
          asDefault = true;
          http.tls.certResolver = "letsencrypt";
        };
      };
      log = {
        level = "INFO";
        filePath = "${config.services.traefik.dataDir}/traefik.log";
        format = "json";
      };
      certificatesResolvers.letsencrypt.acme = {
        email = "postmaster@sunnycareboo.com";
        storage = "${config.services.traefik.dataDir}/acme.json";
        dnsChallenge = {
          provider = "cloudflare";
          resolvers = ["8.8.8.8:53" "8.8.4.4:53"];
        };
      };
      api.dashboard = true;
    };
    dynamicConfigOptions = {
      http = {
        middlewares = {
          oidc-auth = {
            plugin.traefik-oidc-auth = {
              "Provider" = {
                "Url" = "https://pocket-id.sunnycareboo.com";
                "ClientId" = "";
                "ClientSecret" = "";
              };
            };
          };
        };

        services = {
          pocket-id = {
            loadBalancer.servers = [
              {
                url = "http://localhost:1411";
              }
            ];
          };
        };
        routers = {
          to-pocket-id = {
            rule = ''Host(`pocket-id.sunnycareboo.com`)'';
            service = "pocket-id";
            entryPoints = ["websecure"];
          };
          dashboard = {
            rule = ''Host(`traefik.sunnycareboo.com`)'';
            service = "dashboard@internal";
            entryPoints = ["websecure"];
            middlewares = ["oidc-auth"];
          };
          dashboard-api = {
            rule = ''Host(`traefik.sunnycareboo.com`) && PathPrefix(`/api`) || PathPrefix(`/oidc/callback`)'';
            service = "api@internal";
            entryPoints = ["websecure"];
            middlewares = ["oidc-auth"];
          };
        };
      };
    };
  };
}
