{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.chat;
  serverName = config.homelab.domain;
  synapseDomain = config.homelab.services.synapse.domain;

  # nixpkgs's element-web wrapper takes a `conf` arg and merges it onto
  # the upstream config.json — far simpler than overlaying the static
  # tree by hand. Point Element at our homeserver and lock the custom-URL
  # dialog so guests can't accidentally talk to matrix.org.
  elementWeb = pkgs.element-web.override {
    conf = {
      default_server_config."m.homeserver" = {
        base_url = "https://${synapseDomain}";
        server_name = serverName;
      };
      brand = "Sunnycareboo Chat";
      default_theme = "dark";
      disable_custom_urls = true;
      disable_guests = true;
    };
  };
in {
  config = lib.mkMerge [
    {
      homelab.services.chat = {
        isExternal = true;
        # element-web is a static SPA — no backend to proxyPass to. Leaving
        # proxyPass null tells the homelab framework to skip its implicit
        # `/` location so the static-root config below takes over cleanly.
      };
    }
    (lib.mkIf homelabCfg.enable {
      # Compose with the vhost the homelab framework already generates
      # (ACME cert, internal+external listeners, mTLS hooks). NixOS option
      # merging unions both contributors' attrs, so adding `root` + a
      # `/`-location `tryFiles` here doesn't clobber the framework's
      # forceSSL/useACMEHost/listen wiring.
      services.nginx.virtualHosts.${homelabCfg.domain} = {
        root = "${elementWeb}";
        locations."/".tryFiles = "$uri /index.html =404";
      };
    })
  ];
}
