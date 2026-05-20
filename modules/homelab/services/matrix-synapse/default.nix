{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.synapse;
  port = config.homelab.ports.values.matrix-synapse;
  domain = homelabCfg.domain;
  serverName = config.homelab.domain;
  authDomain = config.homelab.services.matrix-auth.domain;
  secretsFile = "${config.services.matrix-synapse.dataDir}/secrets.yaml";

  # MAS↔synapse share two values: the client_secret for synapse's OIDC
  # client registration inside MAS, and the admin token MAS hands to
  # synapse for the /_synapse/admin endpoints. The matrix-auth module
  # writes these here; we LoadCredential them in so synapse never reads
  # the on-disk paths directly under its sandbox.
  masSharedDir = "/var/lib/matrix-mas-shared";

  # MAS listens on this loopback port for token introspection (every
  # authed request). Synapse also discovers MAS's OIDC metadata at
  # startup from `${masPublicBase}/.well-known/openid-configuration`;
  # MAS shares the host so this is effectively a loopback hop through
  # the local nginx, but it does mean MAS must be running and MAS's
  # vhost reachable before synapse will come up.
  masPort = config.homelab.ports.values.matrix-auth;
  masPublicBase = "https://${authDomain}";
in {
  config = lib.mkMerge [
    {
      homelab.services.synapse = {
        isExternal = true;
        # Federation peers + Element X clients arrive without a homelab
        # client cert; the framework's default of `isExternal →
        # mtls.enable` would 403 them on 8443. Auth still gates the
        # server because /_matrix/client/v3/login delegates to MAS.
        mtls.enable = false;
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          client_max_body_size 100M;
          proxy_read_timeout   600s;
        '';
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.matrix-synapse = "auto";

      services.matrix-synapse = {
        enable = true;
        extraConfigFiles = [secretsFile];
        # The module only auto-adds `oidc` (authlib) when settings.oidc_providers
        # is set; MSC3861 delegation uses experimental_features instead, so we
        # have to pull authlib in by hand or synapse refuses to start.
        extras = ["oidc"];
        settings = {
          server_name = serverName;
          public_baseurl = "https://${domain}";
          serve_server_wellknown = false;

          listeners = [
            {
              port = port;
              bind_addresses = ["127.0.0.1"];
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = ["client" "federation"];
                  compress = false;
                }
              ];
            }
          ];

          database = {
            name = "psycopg2";
            allow_unsafe_locale = true;
            args = {
              user = "matrix-synapse";
              database = "matrix-synapse";
              host = "/run/postgresql";
              cp_min = 5;
              cp_max = 10;
            };
          };

          # Registration + password live entirely in MAS. Synapse must
          # have these closed so a misconfig can't accidentally open a
          # parallel login path that bypasses MAS's policies.
          enable_registration = false;
          password_config.enabled = false;

          max_upload_size = "100M";
          url_preview_enabled = true;

          # Synapse's stock rate limits (rc_joins.local: burst=10, then
          # 0.1/sec) are tuned for a public-registration homeserver
          # defending against join-flood spam. On this single-tenant
          # instance the limiter mostly just throttles the mautrix
          # bridges as they back-fill portal rooms — joining 50+ chats
          # after a fresh WhatsApp pairing reliably 429s. The mautrix
          # appservice users are already exempt via `rate_limited: false`
          # in their registration files, but the *human* user joins the
          # invites under their own quota. Bumping the per-user caps
          # high enough to absorb a bridge backfill without making this
          # a fully open relay.
          rc_joins.local = {
            per_second = 10.0;
            burst_count = 500;
          };
          rc_joins.remote = {
            per_second = 1.0;
            burst_count = 100;
          };
          rc_joins_per_room = {
            per_second = 10.0;
            burst_count = 100;
          };
          rc_invites.per_room = {
            per_second = 5.0;
            burst_count = 100;
          };
          rc_invites.per_user = {
            per_second = 5.0;
            burst_count = 100;
          };
          rc_invites.per_issuer = {
            per_second = 5.0;
            burst_count = 100;
          };
          rc_message = {
            per_second = 10.0;
            burst_count = 100;
          };

          # MSC3861 delegates all authentication (login, registration,
          # account management) to MAS at auth.sunnycareboo.com. MAS in
          # turn federates to pocket-id, so the user-facing flow is:
          # Element → synapse → MAS → pocket-id. Element X requires this
          # delegation; legacy `oidc_providers` only spoke `m.login.sso`
          # which Element X explicitly rejects.
          experimental_features.msc3861 = {
            enabled = true;
            issuer = "${masPublicBase}/";
            # Hot path: every authed request goes through introspection.
            # Loopback bypasses the public DNS/TLS hop entirely (synapse
            # only uses the public issuer URL for one-shot OIDC metadata
            # discovery at startup).
            introspection_endpoint = "http://127.0.0.1:${toString masPort}/oauth2/introspect";
            client_id = "0000000000000000000SYNAPSE";
            client_auth_method = "client_secret_basic";
            client_secret_path = "/run/credentials/matrix-synapse.service/mas_synapse_client_secret";
            admin_token_path = "/run/credentials/matrix-synapse.service/mas_admin_token";
            account_management_url = "${masPublicBase}/account";
          };

          # MSC3202 appservice-mode E2EE: lets the mautrix bridges
          # encrypt events as each puppet ghost using a per-puppet
          # device, instead of every ghost masquerading through the
          # bridge bot's single device (which trips Element's
          # "sender doesn't match device owner" shield). The bridges
          # opt in via `encryption.appservice = true` in their config;
          # synapse has to expose four companion endpoints for that
          # to work end-to-end:
          #   - msc3202_transaction_extensions: push device-list /
          #     OTK-count / fallback-key updates for AS users in
          #     /transactions so the bridge knows when to top up keys.
          #   - msc2409_to_device_messages_enabled: include to-device
          #     events in AS transactions. Without this, the bridge
          #     can't receive Megolm session-key shares directed at
          #     its puppets, can't complete the per-puppet device
          #     handshake, and silently falls back to encrypting
          #     puppet events with the bot's single device — i.e. the
          #     exact bug `appservice = true` is meant to fix.
          #     (mau.fi docs list this alongside msc3202 as a hard
          #     requirement for appservice-mode encryption.)
          #   - msc3983_appservice_otk_claims: forward /keys/claim
          #     requests for the bridge's exclusive ghost namespace
          #     to the bridge instead of failing with "no OTKs".
          #   - msc3984_appservice_key_query: forward /keys/query
          #     similarly so other users can fetch ghost device keys.
          # These are orthogonal to MSC3861 — AS-token auth doesn't
          # go through MAS at all.
          experimental_features.msc3202_transaction_extensions = true;
          experimental_features.msc2409_to_device_messages_enabled = true;
          experimental_features.msc3983_appservice_otk_claims = true;
          experimental_features.msc3984_appservice_key_query = true;
        };
      };

      services.postgresql = {
        ensureUsers = [
          {
            name = "matrix-synapse";
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = ["matrix-synapse"];
      };

      systemd.services.matrix-synapse = {
        after = [
          "postgresql.service"
          "matrix-synapse-secrets.service"
          "matrix-authentication-service-secrets.service"
          # MAS itself must be reachable: synapse fetches MAS's OIDC
          # discovery doc at startup (no static issuer_metadata).
          "matrix-authentication-service.service"
        ];
        requires = [
          "postgresql.service"
          "matrix-synapse-secrets.service"
          "matrix-authentication-service-secrets.service"
        ];
        # MAS itself isn't `Requires=` — a transient MAS restart shouldn't
        # cascade-stop synapse. `Wants=` keeps it pulled in at boot but
        # tolerates flaps.
        wants = ["matrix-authentication-service.service"];
        serviceConfig.LoadCredential = [
          "mas_synapse_client_secret:${masSharedDir}/synapse_client_secret"
          "mas_admin_token:${masSharedDir}/admin_token"
        ];
      };

      systemd.services.matrix-synapse-secrets = {
        description = "Generate Synapse macaroon/form secrets if missing";
        before = ["matrix-synapse.service"];
        wantedBy = ["matrix-synapse.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "matrix-synapse";
          Group = "matrix-synapse";
          UMask = "0077";
        };
        script = ''
          set -euo pipefail
          if [ ! -s "${secretsFile}" ]; then
            mac=$(${pkgs.openssl}/bin/openssl rand -base64 48 | tr -d '\n')
            form=$(${pkgs.openssl}/bin/openssl rand -base64 48 | tr -d '\n')
            tmp=$(${pkgs.coreutils}/bin/mktemp "${secretsFile}.XXXXXX")
            {
              echo "macaroon_secret_key: \"$mac\""
              echo "form_secret: \"$form\""
            } > "$tmp"
            mv "$tmp" "${secretsFile}"
          fi
        '';
      };
    })
  ];
}
