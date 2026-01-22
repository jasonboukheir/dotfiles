{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) getExe mkIf mkOption types;
  cfg = config.services.pocket-id;
  jsonFormat = pkgs.formats.json {};

  secretsDir = "/run/pocket-id-secrets";

  exportCredentials = n: _: ''export ${n}="$(${pkgs.systemd}/bin/systemd-creds cat ${n}_FILE)"'';
  exportAllCredentials = vars: lib.concatStringsSep "\n" (lib.mapAttrsToList exportCredentials vars);
  getLoadCredentialList = lib.mapAttrsToList (n: v: "${n}_FILE:${v}") cfg.credentials;

  pocket-id-bootstrap = pkgs.writeShellApplication {
    name = "pocket-id-bootstrap";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      set -e
      CONFIG_FILE="$1"
      API_URL="$2"
      SECRETS_DIR="$3"
      STATIC_TOKEN="$4"

      # Timeout Configuration
      MAX_RETRIES=5
      count=0

      echo "Waiting for Pocket ID at $API_URL..."

      # Loop with timeout
      until curl -s -o /dev/null -w "%{http_code}" "$API_URL/healthz" | grep -q "204"; do
        if [ "$count" -ge "$MAX_RETRIES" ]; then
          echo "Error: Timed out waiting for Pocket ID to become healthy after $MAX_RETRIES seconds."
          exit 1
        fi
        sleep 1
        count=$((count + 1))
      done

      echo "Pocket ID is online. Starting provisioning..."

      mkdir -p "$SECRETS_DIR"

      jq -c '.[]' "$CONFIG_FILE" | while read -r client_json; do
        CLIENT_ID=$(echo "$client_json" | jq -r '.id')

        # Check existence
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "X-API-Key: $STATIC_TOKEN" \
          "$API_URL/api/oidc/clients/$CLIENT_ID")

        if [ "$HTTP_CODE" -eq 404 ]; then
          echo "Creating client: $CLIENT_ID"
          curl -s -X POST "$API_URL/api/oidc/clients" \
            -H "X-API-Key: $STATIC_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$client_json" > /dev/null
        else
          echo "Updating client: $CLIENT_ID"
          curl -s -X PUT "$API_URL/api/oidc/clients/$CLIENT_ID" \
            -H "X-API-Key: $STATIC_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$client_json" > /dev/null
        fi

        # Secret Management
        SECRET_FILE="$SECRETS_DIR/$CLIENT_ID"
        if [ ! -f "$SECRET_FILE" ]; then
          echo "Generating new secret for $CLIENT_ID..."
          SECRET_PAYLOAD=$(curl -s -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/secret" \
            -H "X-API-Key: $STATIC_TOKEN" \
            -H "Content-Length: 0")

          SECRET_VAL=$(echo "$SECRET_PAYLOAD" | jq -r '.secret')

          if [ -n "$SECRET_VAL" ] && [ "$SECRET_VAL" != "null" ]; then
            echo -n "$SECRET_VAL" > "$SECRET_FILE"
            chmod 600 "$SECRET_FILE"
          else
            echo "Error: Failed to retrieve secret from API response."
            exit 1
          fi
        fi
      done
    '';
  };
in {
  options.services.pocket-id = {
    credentials = mkOption {
      type = types.attrsOf types.path;
      default = {};
      example = {
        ENCRYPTION_KEY = "/run/secrets/pocket-id/encryption-key";
      };
      description = ''
        Environment variables which are loaded from the contents of the specified file paths.
        This can be used to securely store tokens and secrets outside of the world-readable Nix store.
      '';
    };

    ensureClients = mkOption {
      description = "Declarative OIDC client management.";
      default = {};
      type = types.attrsOf (types.submodule ({
        name,
        config,
        ...
      }: {
        freeformType = jsonFormat.type;
        options = {
          id = mkOption {
            type = types.str;
            default = name;
            description = "The Client ID (defaults to attribute name).";
          };
          name = mkOption {
            type = types.str;
            default = name;
            description = "Friendly name for the client.";
          };
          isPublic = mkOption {
            type = types.bool;
            default = false;
            description = "whether client has a secret or not";
          };
          pkceEnabled = mkOption {
            type = types.bool;
            default = true;
            description = "has pkce enabled or not";
          };
          callbackURLs = mkOption {
            type = types.listOf types.str;
            default = [];
          };

          secretFile = mkOption {
            type = types.path;
            readOnly = true;
            # Resolves to: /run/pocket-id-secrets/<client_id>
            default = "${secretsDir}/${config.id}";
            description = "The expected path to the secret file for this client. Use this in other modules.";
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    systemd.services.pocket-id = {
      serviceConfig = {
        LoadCredential = getLoadCredentialList;
        ExecStart = lib.mkForce (pkgs.writeShellScript "pocket-id-start" ''
          ${exportAllCredentials cfg.credentials}
          exec ${getExe cfg.package}
        '');
      };
    };

    systemd.services.pocket-id-provisioner = mkIf (cfg.ensureClients != {}) (let
      clientsConfigFile = jsonFormat.generate "pocket-id-clients.json" (lib.attrValues cfg.ensureClients);
    in {
      description = "Provision Pocket ID OIDC Clients";
      after = ["pocket-id.service"];
      wants = ["pocket-id.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        RuntimeDirectory = baseNameOf secretsDir;
        LoadCredential = ["static_api_key:${cfg.credentials.STATIC_API_KEY}"];
        RemainAfterExit = true;
      };

      script = ''
        API_KEY=$(cat "$CREDENTIALS_DIRECTORY/static_api_key")

        ${pocket-id-bootstrap}/bin/pocket-id-bootstrap \
          "${clientsConfigFile}" \
          "http://127.0.0.1:${toString cfg.settings.PORT or "8080"}" \
          "$RUNTIME_DIRECTORY" \
          "$API_KEY"
      '';
    });
  };
}
