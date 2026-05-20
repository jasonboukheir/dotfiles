{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.chat;
  port = config.homelab.ports.values.matrix-synapse;
  domain = homelabCfg.domain;
  serverName = config.homelab.domain;
  apexVhost = serverName;
  oidcCfg = config.services.pocket-id.ensureClients.matrix-synapse;
  idDomain = config.homelab.services.id.domain;
  secretsFile = "${config.services.matrix-synapse.dataDir}/secrets.yaml";

  wellKnownServer = builtins.toJSON {"m.server" = "${domain}:443";};
  wellKnownClient = builtins.toJSON {"m.homeserver" = {base_url = "https://${domain}";};};
in {
  config = lib.mkMerge [
    {
      homelab.services.chat = {
        isExternal = true;
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
        extras = ["oidc"];
        extraConfigFiles = [secretsFile];
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

          enable_registration = false;
          password_config.enabled = false;

          max_upload_size = "100M";
          url_preview_enabled = true;

          oidc_providers = [
            {
              idp_id = "pocketid";
              idp_name = "Pocket ID";
              idp_brand = "oauth";
              issuer = "https://${idDomain}";
              client_id = oidcCfg.settings.id;
              client_secret_path = "/run/credentials/matrix-synapse.service/oidc_client_secret";
              discover = true;
              scopes = ["openid" "profile" "email"];
              user_mapping_provider.config = {
                localpart_template = "{{ user.preferred_username }}";
                display_name_template = "{{ user.name }}";
                email_template = "{{ user.email }}";
              };
              backchannel_logout_enabled = true;
            }
          ];
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
        after = ["postgresql.service" "matrix-synapse-secrets.service" "pocket-id-provisioner.service"];
        requires = ["postgresql.service" "matrix-synapse-secrets.service"];
        serviceConfig.LoadCredential = [
          "oidc_client_secret:${oidcCfg.secretFile}"
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

      services.pocket-id.ensureClients.matrix-synapse = {
        dependentServices = [config.systemd.services.matrix-synapse.name];
        settings = {
          name = "Matrix";
          launchURL = "https://${domain}";
          callbackURLs = [
            "https://${domain}/_synapse/client/oidc/callback"
          ];
        };
      };

      services.nginx.virtualHosts.${apexVhost}.locations = {
        "= /.well-known/matrix/server" = {
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${wellKnownServer}';
          '';
        };
        "= /.well-known/matrix/client" = {
          extraConfig = ''
            default_type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${wellKnownClient}';
          '';
        };
      };
    })
  ];
}
