{
  writeShellApplication,
  curl,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "pocket-id-bootstrap";
  runtimeInputs = [curl jq coreutils];
  text = ''
    set -e
    CONFIG_FILE="$1"
    API_URL="$2"
    SECRETS_DIR="$3"
    STATIC_TOKEN="$4"

    # Timeout Configuration
    MAX_RETRIES=30 # Increased to 30s to be safe
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

    # Read the entire array, but process objects one by one
    jq -c '.[]' "$CONFIG_FILE" | while read -r client_json; do
      CLIENT_ID=$(echo "$client_json" | jq -r '.id')
      IS_PUBLIC=$(echo "$client_json" | jq -r '.isPublic // false')

      # Extract logo paths (if they exist)
      LOGO_PATH=$(echo "$client_json" | jq -r '.logo // empty')
      DARK_LOGO_PATH=$(echo "$client_json" | jq -r '.darkLogo // empty')

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

      # --- LOGO UPLOAD LOGIC ---
      if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
        echo "Uploading light logo for $CLIENT_ID..."
        curl -s -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/logo?light=true" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -F "file=@$LOGO_PATH" > /dev/null
      fi

      if [ -n "$DARK_LOGO_PATH" ] && [ -f "$DARK_LOGO_PATH" ]; then
        echo "Uploading dark logo for $CLIENT_ID..."
        curl -s -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/logo?light=false" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -F "file=@$DARK_LOGO_PATH" > /dev/null
      fi
      # -------------------------

      # Secret Management (Skip for public clients)
      if [ "$IS_PUBLIC" != "true" ]; then
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
      else
        echo "Skipping secret generation for public client: $CLIENT_ID"
      fi
    done
  '';
}
