{config, ...}: {
  services.traefik = {
    enable = true;
    environmentFiles = [
      "/var/lib/secrets/sunnycareboo.com.cloudflare.token"
    ];
    staticConfigOptions = {
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
        routers = {
          dashboard = {
            rule = ''Host(`traefik.sunnycareboo.com`) && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))'';
            service = "api@internal";
            entryPoints = ["websecure"];
          };
        };
      };
    };
  };
}
