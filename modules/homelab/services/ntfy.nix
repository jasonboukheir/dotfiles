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

      # On this host the public name `ntfy.sunnycareboo.com` resolves to the
      # tailnet IP (100.64.0.7) via MagicDNS. Synapse's default
      # `ip_range_blacklist` covers the entire 100.64.0.0/10 CGNAT range as
      # an SSRF guard, so its push gateway POSTs to ntfy fail with a
      # `DNSLookupError no results for hostname lookup` (the IP is found
      # then dropped). Pinning the name to loopback for *local* lookups
      # makes Synapse hit nginx on this box directly — TLS still validates
      # because nginx serves the LE cert keyed off SNI, not the dest IP —
      # without having to widen the SSRF guard across CGNAT or split the
      # ntfy `base-url` (which has to keep matching the public pushkey, or
      # the Matrix Push Gateway will reject every pusher).
      networking.hosts."127.0.0.1" = [domain];

      # The hosts override above is necessary but not sufficient: synapse's
      # default `ip_range_blacklist` *also* covers 127.0.0.0/8, so once DNS
      # resolves to loopback the request is still dropped with the same
      # "DNSLookupError no results for hostname lookup" (Twisted reports it
      # as a DNS failure rather than a connect-time deny). Whitelisting the
      # specific /32 carves out exactly the dest we just pinned and nothing
      # else — narrower than `127.0.0.0/8`, which would also unblock any
      # other localhost service a hostile pusher URL could probe. Scoped
      # into the ntfy module rather than synapse's so the SSRF relaxation
      # disappears the moment ntfy does.
      services.matrix-synapse.settings.ip_range_whitelist = lib.mkIf config.services.matrix-synapse.enable ["127.0.0.1/32"];

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
          # No web UI: this server exists for UnifiedPush + the Matrix
          # Push Gateway, both of which are pure-API flows. Serving the
          # SPA at / only advertises the service to the public internet
          # and creates a regression surface if an upstream default flip
          # (enable-signup, enable-login) ever turns the bundled client
          # into a self-serve account-creation page. The API stays
          # reachable; only / and /static stop responding.
          web-root = "disable";
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
