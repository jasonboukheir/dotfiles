{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.pocket-id;

  # Format helper to turn Nix sets into JSON for the CLI
  jsonFormat = pkgs.formats.json {};

  # --- 1. THE BOOTSTRAP PACKAGE ---
  # This corresponds to lldap-bootstrap in your example.
  # It handles the API logic using curl and jq.
  pocket-id-bootstrap = pkgs.writeShellApplication {
    name = "pocket-id-bootstrap";
    runtimeInputs = [pkgs.curl pkgs.jq pkgs.coreutils];
    text = ''
      set -e

      # Arguments
      CONFIG_FILE="$1"
      API_URL="$2"
      SECRETS_DIR="$3"
      STATIC_TOKEN="$4"

      # Headers
      AUTH_HEADER="Authorization: Bearer $STATIC_TOKEN"
      JSON_HEADER="Content-Type: application/json"

      echo "Waiting for Pocket ID at $API_URL..."
      # Use healthz endpoint as per spec
      until curl -s -o /dev/null -w "%{http_code}" "$API_URL/healthz" | grep -q "204"; do
        sleep 1
      done
      echo "Pocket ID is online."

      # Create directory for secrets if it doesn't exist
      mkdir -p "$SECRETS_DIR"

      # Loop through clients defined in the JSON file
      jq -c '.[]' "$CONFIG_FILE" | while read -r client_json; do

        # Extract ID and Name
        CLIENT_ID=$(echo "$client_json" | jq -r '.id')
        CLIENT_NAME=$(echo "$client_json" | jq -r '.name')

        echo "Processing Client: $CLIENT_NAME ($CLIENT_ID)"

        # 1. Check if client exists (GET /api/oidc/clients/{id})
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
          -H "$AUTH_HEADER" \
          "$API_URL/api/oidc/clients/$CLIENT_ID")

        if [ "$HTTP_CODE" -eq 404 ]; then
          # --- CREATE ---
          echo "  - Client not found. Creating..."
          curl -s -X POST "$API_URL/api/oidc/clients" \
            -H "$AUTH_HEADER" -H "$JSON_HEADER" \
            -d "$client_json" > /dev/null
        else
          # --- UPDATE ---
          echo "  - Client exists. Updating metadata..."
          curl -s -X PUT "$API_URL/api/oidc/clients/$CLIENT_ID" \
            -H "$AUTH_HEADER" -H "$JSON_HEADER" \
            -d "$client_json" > /dev/null
        fi

        # 2. Handle Secrets
        # The API only allows generating a NEW secret. We cannot read the current one.
        # To avoid breaking sessions on every deploy, we only generate if we don't have one on disk.
        SECRET_FILE="$SECRETS_DIR/$CLIENT_ID"

        if [ ! -f "$SECRET_FILE" ]; then
          echo "  - No local secret found. Rotated secret via API."

          # POST /api/oidc/clients/{id}/secret returns { "secret": "..." }
          SECRET_PAYLOAD=$(curl -s -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/secret" \
            -H "$AUTH_HEADER" \
            -H "Content-Length: 0")

          SECRET_VALUE=$(echo "$SECRET_PAYLOAD" | jq -r '.secret')

          if [ -n "$SECRET_VALUE" ] && [ "$SECRET_VALUE" != "null" ]; then
            echo -n "$SECRET_VALUE" > "$SECRET_FILE"
            chmod 600 "$SECRET_FILE"
            echo "  - Secret written to $SECRET_FILE"
          else
            echo "  - ERROR: Failed to retrieve secret."
            exit 1
          fi
        else
          echo "  - Secret file exists. Skipping rotation."
        fi
      done
    '';
  };
in {
  # --- 2. DEFINE OPTIONS ---
  options.services.pocket-id = with lib; {
    # Add this to the existing pocket-id module options
    ensureClients = mkOption {
      description = "Declarative OIDC client management.";
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = jsonFormat.type;
        options = {
          id = mkOption {
            type = types.str;
            default = name;
            description = "The Client ID. Defaults to the attribute name.";
          };
          name = mkOption {
            type = types.str;
            default = name;
            description = "Friendly name for the client.";
          };
          callbackURLs = mkOption {
            type = types.listOf types.str;
            default = [];
          };
          launchURL = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          # Define other spec fields as needed, or rely on freeformType
        };
      }));
    };
  };

  # --- 3. IMPLEMENTATION ---
  config = lib.mkIf (cfg.enable && cfg.ensureClients != {}) {
    # Create the config file for the script
    # We convert the attrSet to a list for easier processing in bash
    systemd.services.pocket-id-provisioner = let
      clientsList = lib.attrValues cfg.ensureClients;
      clientsConfigFile = jsonFormat.generate "pocket-id-clients.json" clientsList;
    in {
      description = "Provision Pocket ID OIDC Clients";
      after = ["pocket-id.service"];
      wants = ["pocket-id.service"];
      wantedBy = ["multi-user.target"];

      # Load the static API key.
      # ASSUMPTION: You have configured a static key for Pocket ID.
      # Replace /path/to/key with your actual secret path or sops-nix path.
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Access the static key securely
        LoadCredential = "static_api_key:${config.sops.secrets.pocket_id_static_key.path}";
      };

      script = ''
        # Retrieve key from systemd credentials
        API_KEY=$(cat "$CREDENTIALS_DIRECTORY/static_api_key")

        # Run bootstrap
        ${pocket-id-bootstrap}/bin/pocket-id-bootstrap \
          "${clientsConfigFile}" \
          "http://127.0.0.1:${toString cfg.settings.port}" \
          "/run/pocket-id-secrets" \
          "$API_KEY"
      '';
    };
  };
}
