{
  config,
  lib,
  ...
}: let
  homelabCfg = config.homelab.services.ntfy;
  port = config.homelab.ports.values.ntfy;
  domain = homelabCfg.domain;
in {
  config = lib.mkMerge [
    {
      homelab.services.ntfy = {
        isExternal = true;
        # UnifiedPush clients (FCM-less Android via the ntfy app) reach this
        # vhost from arbitrary networks without a homelab client cert; the
        # framework's `isExternal → mtls.enable` default would 403 them.
        mtls.enable = false;
        proxyPass = "http://127.0.0.1:${toString port}";
        # ntfy uses long-poll/SSE/WebSocket for subscriptions; the default
        # 60s upstream timeout severs idle subscribers and forces clients
        # into reconnect storms that look like missed pushes.
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.ntfy = "auto";

      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://${domain}";
          listen-http = "127.0.0.1:${toString port}";
          behind-proxy = true;
        };
      };
    })
  ];
}
