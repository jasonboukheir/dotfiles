{config, ...}: {
  services.nginx = {
    enable = true;
    recommendedProxySettings = true; # Optional but good for reverse proxies
    recommendedTlsSettings = true; # Optional for better TLS defaults

    virtualHosts = {
      "blocky.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:1501"; # Proxies to your blocky instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };
      "budget.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:3000"; # Proxies to your blocky instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };
      "ai.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:3100"; # Proxies to your blocky instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };
      "litellm.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:3200"; # Proxies to your blocky instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };
      "pocket-id.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:1411"; # Proxies to your pocket-id instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };
      "jellyfin.sunnycareboo.com" = {
        forceSSL = true; # Redirects HTTP to HTTPS
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:8096"; # Proxies to your jellyfin instance
          proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
        };
      };

      # nixarr
      "transmission.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:9091";
          proxyWebsockets = true;
        };
      };
      "bazarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:6767";
          proxyWebsockets = true;
        };
      };
      "lidarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:8686";
          proxyWebsockets = true;
        };
      };
      "prowlarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:9696";
          proxyWebsockets = true;
        };
      };
      "radarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:7878";
          proxyWebsockets = true;
        };
      };
      "readarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:8787";
          proxyWebsockets = true;
        };
      };
      "sonarr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:8989";
          proxyWebsockets = true;
        };
      };
      "jellyseerr.sunnycareboo.com" = {
        forceSSL = true;
        enableACME = true;
        acmeRoot = null;
        locations."/" = {
          proxyPass = "http://localhost:5055";
          proxyWebsockets = true;
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "postmaster@sunnycareboo.com";
      dnsProvider = "cloudflare";
      # Assumes your sops secret contains the necessary Cloudflare credentials,
      # e.g., CF_API_EMAIL=... and CF_API_KEY=..., or CF_DNS_API_TOKEN=...
      # Adjust the secret path if you use a different one.
      environmentFile = config.sops.secrets."traefik/env".path;
    };
  };
}
