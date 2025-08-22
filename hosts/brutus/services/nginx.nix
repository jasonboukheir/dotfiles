{config, ...}: {
  services.nginx = {
    enable = true;
    recommendedProxySettings = true; # Optional but good for reverse proxies
    recommendedTlsSettings = true; # Optional for better TLS defaults

    # virtualHosts = {
    #   "pocket-id.sunnycareboo.com" = {
    #     forceSSL = true; # Redirects HTTP to HTTPS
    #     enableACME = true; # Enables Let's Encrypt cert provisioning
    #     locations."/" = {
    #       proxyPass = "http://localhost:1411"; # Proxies to your pocket-id instance
    #       proxyWebsockets = true; # If needed for WebSocket support; adjust as necessary
    #     };
    #   };
    # };
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "postmaster@sunnycareboo.com";
    };
    certs."pocket-id.sunnycareboo.com" = {
      dnsProvider = "cloudflare";
      # Assumes your sops secret contains the necessary Cloudflare credentials,
      # e.g., CF_API_EMAIL=... and CF_API_KEY=..., or CF_DNS_API_TOKEN=...
      # Adjust the secret path if you use a different one.
      environmentFile = config.sops.secrets."traefik/env".path;
    };
  };
}
