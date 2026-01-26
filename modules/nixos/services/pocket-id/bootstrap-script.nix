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
    # 1. Enable Debug mode (prints commands as they run)
    set -x

    CONFIG_FILE="$1"
    API_URL="$2"
    SECRETS_DIR="$3"
    STATIC_TOKEN="$4"

    # Timeout Configuration
    MAX_RETRIES=30
    count=0

    echo "Waiting for Pocket ID at $API_URL..."

    until curl -s -o /dev/null -w "%{http_code}" "$API_URL/healthz" | grep -q "204"; do
      if [ "$count" -ge "$MAX_RETRIES" ]; then
        echo "Error: Timed out waiting for Pocket ID to become healthy."
        exit 1
      fi
      sleep 1
      count=$((count + 1))
    done

    echo "Pocket ID is online. Starting provisioning..."

    mkdir -p "$SECRETS_DIR"

    # Read array, process objects
    jq -c '.[]' "$CONFIG_FILE" | while read -r client_json; do
      CLIENT_ID=$(echo "$client_json" | jq -r '.id')
      IS_PUBLIC=$(echo "$client_json" | jq -r '.isPublic // false')
      LOGO_PATH=$(echo "$client_json" | jq -r '.logo // empty')
      DARK_LOGO_PATH=$(echo "$client_json" | jq -r '.darkLogo // empty')

      echo "Processing Client ID: $CLIENT_ID"

      # Check existence
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-API-Key: $STATIC_TOKEN" \
        "$API_URL/api/oidc/clients/$CLIENT_ID")

      # 2. Capture output to variable (RESPONSE) instead of /dev/null
      if [ "$HTTP_CODE" -eq 404 ]; then
        echo "Creating client: $CLIENT_ID"
        RESPONSE=$(curl -sS -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL/api/oidc/clients" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -H "Content-Type: application/json" \
          -d "$client_json")
      else
        echo "Updating client: $CLIENT_ID"
        RESPONSE=$(curl -sS -w "\nHTTP_STATUS:%{http_code}" -X PUT "$API_URL/api/oidc/clients/$CLIENT_ID" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -H "Content-Type: application/json" \
          -d "$client_json")
      fi

      # 3. Check for failure in the response we just captured
      # If the status code at the end of the response is 400 or greater, print error and exit.
      RESPONSE_CODE=$(echo "$RESPONSE" | tail -n1 | cut -d: -f2)
      if [ "$RESPONSE_CODE" -ge 400 ]; then
         echo "!!! API ERROR !!!"
         echo "Client ID: $CLIENT_ID"
         echo "Response Body: $RESPONSE"
         exit 1
      fi

      # --- LOGO UPLOAD LOGIC ---
      if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
        echo "Uploading light logo for $CLIENT_ID..."
        # Removed > /dev/null to allow errors to surface in logs
        curl -sS -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/logo?light=true" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -F "file=@$LOGO_PATH"
      fi

      if [ -n "$DARK_LOGO_PATH" ] && [ -f "$DARK_LOGO_PATH" ]; then
        echo "Uploading dark logo for $CLIENT_ID..."
        curl -sS -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/logo?light=false" \
          -H "X-API-Key: $STATIC_TOKEN" \
          -F "file=@$DARK_LOGO_PATH"
      fi

      # Secret Management
      if [ "$IS_PUBLIC" != "true" ]; then
        SECRET_FILE="$SECRETS_DIR/$CLIENT_ID"
        if [ ! -f "$SECRET_FILE" ]; then
          echo "Generating new secret for $CLIENT_ID..."

          # Added -S to curl to show errors if it fails
          SECRET_PAYLOAD=$(curl -sS -X POST "$API_URL/api/oidc/clients/$CLIENT_ID/secret" \
            -H "X-API-Key: $STATIC_TOKEN" \
            -H "Content-Length: 0")

          SECRET_VAL=$(echo "$SECRET_PAYLOAD" | jq -r '.secret')

          if [ -n "$SECRET_VAL" ] && [ "$SECRET_VAL" != "null" ]; then
            echo -n "$SECRET_VAL" > "$SECRET_FILE"
            chmod 600 "$SECRET_FILE"
          else
            echo "Error: Failed to retrieve secret from API response."
            echo "Payload was: $SECRET_PAYLOAD"
            exit 1
          fi
        fi
      fi
    done
  '';
}
