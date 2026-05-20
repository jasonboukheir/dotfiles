{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.matrix-auth;
  port = config.homelab.ports.values.matrix-auth;
  domain = homelabCfg.domain;
  serverName = config.homelab.domain;
  synapseDomain = config.homelab.services.synapse.domain;
  idDomain = config.homelab.services.id.domain;
  pocketIdCfg = config.services.pocket-id.ensureClients.matrix-auth;

  # MAS requires a stable ULID per upstream OAuth2 provider — the
  # provider's callback URL is derived from it, so pocket-id's
  # callbackURLs and MAS's provider config must agree. Pinning a
  # constant ULID keeps the URL stable across rebuilds.
  pocketIdProviderUlid = "01J84PV2DBJ7HXR8FK1Q90WV0Z";

  # MAS uses ULID-format client IDs throughout. `0000000000000000000SYNAPSE`
  # is the synapse client_id that pairs the experimental_features.msc3861
  # block in matrix-synapse with the matching `clients` entry MAS gets
  # via the secrets.yaml overlay below.
  synapseClientId = "0000000000000000000SYNAPSE";

  masSharedDir = "/var/lib/matrix-mas-shared";
  masStateDir = "/var/lib/matrix-authentication-service";
  masSecretsFile = "${masStateDir}/secrets.yaml";
  masConfigFile = "/etc/matrix-authentication-service/config.yaml";

  yamlFormat = pkgs.formats.yaml {};

  # Static portion of MAS config. The dynamic secrets (encryption key,
  # JWT signing keys, matrix.secret, clients[].client_secret) live in a
  # separate runtime-generated overlay (masSecretsFile) so they never
  # land in the Nix store world-readable.
  staticConfig = {
    http = {
      listeners = [
        {
          name = "web";
          resources = [
            {name = "discovery";}
            {name = "human";}
            {name = "oauth";}
            {name = "compat";}
            {name = "graphql";}
            {name = "assets";}
          ];
          binds = [
            {
              host = "127.0.0.1";
              port = port;
            }
          ];
          proxy_protocol = false;
        }
      ];
      trusted_proxies = ["127.0.0.0/8"];
      public_base = "https://${domain}/";
      issuer = "https://${domain}/";
    };

    database = {
      uri = "postgresql:///matrix-authentication-service?host=/run/postgresql";
    };

    matrix = {
      homeserver = serverName;
      endpoint = "https://${synapseDomain}/";
    };

    passwords.enabled = false;

    account = {
      password_registration_enabled = false;
      password_login_enabled = false;
      password_change_allowed = false;
      password_recovery_enabled = false;
      email_change_allowed = true;
      displayname_change_allowed = true;
      account_deactivation_allowed = true;
      registration_token_required = false;
    };

    upstream_oauth2.providers = [
      {
        id = pocketIdProviderUlid;
        issuer = "https://${idDomain}";
        human_name = "Pocket ID";
        brand_name = "oauth2";
        client_id = pocketIdCfg.settings.id;
        client_secret_file = "/run/credentials/matrix-authentication-service.service/pocket_id_client_secret";
        token_endpoint_auth_method = "client_secret_basic";
        scope = "openid profile email";
        discovery_mode = "oidc";
        claims_imports = {
          localpart = {
            action = "require";
            template = "{{ user.preferred_username }}";
          };
          displayname = {
            action = "suggest";
            template = "{{ user.name }}";
          };
          email = {
            action = "suggest";
            set_email_verification = "always";
            template = "{{ user.email }}";
          };
        };
      }
    ];

    # No SMTP wiring needed while password flows are disabled — every
    # outbound notification email comes through pocket-id's transport
    # instead. blackhole = silently drop anything MAS tries to send.
    email.transport = "blackhole";
  };

  staticConfigFile = yamlFormat.generate "matrix-authentication-service-config.yaml" staticConfig;
in {
  config = lib.mkMerge [
    {
      homelab.services.matrix-auth = {
        isExternal = true;
        # Element X mobile + federation peers reach MAS without a
        # homelab CA cert; mTLS would block them. Browser flows from
        # Element Web also land here without the chat-vhost cert
        # context.
        mtls.enable = false;
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          proxy_read_timeout 60s;
        '';
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.matrix-auth = "auto";

      users.users.matrix-authentication-service = {
        isSystemUser = true;
        group = "matrix-authentication-service";
        home = masStateDir;
      };
      users.groups.matrix-authentication-service = {};

      services.postgresql = {
        ensureUsers = [
          {
            name = "matrix-authentication-service";
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = ["matrix-authentication-service"];
      };

      environment.etc."matrix-authentication-service/config.yaml".source = staticConfigFile;

      systemd.tmpfiles.rules = [
        "d ${masStateDir} 0750 matrix-authentication-service matrix-authentication-service - -"
        "d ${masSharedDir} 0750 root root - -"
      ];

      # One-shot that materializes the dynamic secrets MAS needs:
      # - secrets.encryption: 32-byte hex token-encryption key
      # - secrets.keys: RSA + EC JWT signing keys
      # - matrix.secret: admin token MAS shares with synapse for the
      #                  /_synapse/admin endpoints
      # - clients[].client_secret: synapse's MAS-side OIDC client secret
      #
      # The same admin token and synapse client secret get mirrored to
      # ${masSharedDir} so matrix-synapse can LoadCredential them in
      # without ever opening MAS-owned files directly.
      systemd.services.matrix-authentication-service-secrets = {
        description = "Generate Matrix Authentication Service secrets if missing";
        before = [
          "matrix-authentication-service.service"
          "matrix-synapse.service"
        ];
        wantedBy = [
          "matrix-authentication-service.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        path = [pkgs.openssl pkgs.coreutils];
        script = ''
          set -euo pipefail

          if [ -s ${masSecretsFile} ] \
             && [ -s ${masSharedDir}/admin_token ] \
             && [ -s ${masSharedDir}/synapse_client_secret ]; then
            exit 0
          fi

          install -d -m 0750 -o matrix-authentication-service -g matrix-authentication-service ${masStateDir}
          install -d -m 0750 -o root -g root ${masSharedDir}

          enc=$(openssl rand -hex 32)
          admin=$(openssl rand -base64 48 | tr -d '\n=+/' | head -c 64)
          syn_client=$(openssl rand -base64 48 | tr -d '\n=+/' | head -c 64)

          rsa_pem=$(openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null)
          ec_pem=$(openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:prime256v1 2>/dev/null)

          # Indent each PEM line by 8 spaces so it sits cleanly under
          # the YAML literal-block scalar `key: |`.
          indent_pem() { sed 's/^/        /'; }

          tmp=$(mktemp ${masSecretsFile}.XXXXXX)
          {
            echo "secrets:"
            echo "  encryption: \"$enc\""
            echo "  keys:"
            echo "    - kid: rsa-1"
            echo "      key: |"
            printf '%s\n' "$rsa_pem" | indent_pem
            echo "    - kid: ec-1"
            echo "      key: |"
            printf '%s\n' "$ec_pem" | indent_pem
            echo "matrix:"
            echo "  secret: \"$admin\""
            echo "clients:"
            echo "  - client_id: ${synapseClientId}"
            echo "    client_auth_method: client_secret_basic"
            echo "    client_secret: \"$syn_client\""
          } > "$tmp"
          chmod 0640 "$tmp"
          chown matrix-authentication-service:matrix-authentication-service "$tmp"
          mv "$tmp" ${masSecretsFile}

          umask 077
          printf '%s' "$admin" > ${masSharedDir}/admin_token
          printf '%s' "$syn_client" > ${masSharedDir}/synapse_client_secret
          chmod 0600 ${masSharedDir}/admin_token ${masSharedDir}/synapse_client_secret
        '';
      };

      systemd.services.matrix-authentication-service = {
        description = "Matrix Authentication Service";
        after = [
          "network.target"
          "postgresql.service"
          "matrix-authentication-service-secrets.service"
          "pocket-id-provisioner.service"
        ];
        requires = [
          "postgresql.service"
          "matrix-authentication-service-secrets.service"
        ];
        wants = ["pocket-id-provisioner.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          User = "matrix-authentication-service";
          Group = "matrix-authentication-service";
          StateDirectory = "matrix-authentication-service";
          LoadCredential = [
            "pocket_id_client_secret:${pocketIdCfg.secretFile}"
          ];
          ExecStartPre = "${lib.getExe pkgs.matrix-authentication-service} database migrate --config ${masConfigFile} --config ${masSecretsFile}";
          ExecStart = "${lib.getExe pkgs.matrix-authentication-service} server --config ${masConfigFile} --config ${masSecretsFile}";
          Restart = "on-failure";
          RestartSec = "5s";

          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          ReadOnlyPaths = [masStateDir "/etc/matrix-authentication-service"];
        };
      };

      services.pocket-id.ensureClients.matrix-auth = {
        dependentServices = [config.systemd.services.matrix-authentication-service.name];
        settings = {
          name = "Matrix";
          launchURL = "https://${domain}";
          callbackURLs = [
            "https://${domain}/upstream/callback/${pocketIdProviderUlid}"
          ];
        };
      };
    })
  ];
}
