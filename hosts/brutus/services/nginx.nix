{
  config,
  lib,
  ...
}: let
  services = {
    ai = {port = 3100;};
    blocky = {port = 1501;};
    budget = {port = 3000;};
    "litellm.ai" = {port = 3200;};
    "pocket-id" = {port = 1411;};
    jellyfin = {port = 8096;};

    # nixarr
    transmission = {port = 9091;};
    bazarr = {port = 6767;};
    lidarr = {port = 8686;};
    prowlarr = {port = 9696;};
    radarr = {port = 7878;};
    readarr = {port = 8787;};
    sonarr = {port = 8989;};
    jellyseerr = {port = 5055;};
  };
  mkVirtualHost = subdomain: config:
    lib.nameValuePair "${subdomain}.sunnycareboo.com" {
      forceSSL = true;
      enableACME = true;
      acmeRoot = null;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.port}";
        proxyWebsockets = true;
      };
    };
in {
  services.nginx = {
    enable = true;
    recommendedProxySettings = true; # Optional but good for reverse proxies
    recommendedTlsSettings = true; # Optional for better TLS defaults

    virtualHosts =
      lib.mapAttrs' mkVirtualHost services;
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
