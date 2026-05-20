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
          # base-url has a second job beyond UnifiedPush endpoint
          # construction: ntfy's built-in Matrix Push Gateway (always-on,
          # served at /_matrix/push/v1/notify) uses it to validate the
          # `pushkey` Synapse posts to. Pushkeys that don't start with
          # `${base-url}/` are bounced back to Synapse in the
          # `rejected_pushkeys` array, which deletes the pusher. There
          # is no `matrix-gateway-enabled` flag — base-url is the gate.
          base-url = "https://${domain}";
          listen-http = "127.0.0.1:${toString port}";
          behind-proxy = true;
          # Default-deny so a freshly deployed server is not open-write
          # to the public internet. Family accounts + the anonymous
          # write-only grant on `up*` (for UnifiedPush) are layered on
          # imperatively via `ntfy user add` / `ntfy access` — there is
          # no LDAP/OIDC integration upstream (binwiederhier/ntfy#296,
          # #1596), so the user.db is the source of truth.
          auth-default-access = "deny-all";
          # Charge rate-limit quota to the subscriber instead of the
          # publisher. Without this, an upstream that POSTs to a stale
          # UnifiedPush endpoint (subscriber-less topic) burns the
          # server-wide visitor budget; with it set, the topic returns
          # 507 and the publisher backs off.
          visitor-subscriber-rate-limiting = true;
        };
      };
    })
  ];
}
