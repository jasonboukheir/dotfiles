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
  sharedKeyDir = "/run/pocket-id-shared";
  generatedApiKeyPath = "${sharedKeyDir}/api_key";

  # Determine if we should use the generated key or a user-provided one
  useGeneratedKey = ! (cfg.credentials ? STATIC_API_KEY);
  finalApiKeyPath =
    if useGeneratedKey
    then generatedApiKeyPath
    else cfg.credentials.STATIC_API_KEY;

  # Combine user credentials with the generated key if needed
  effectiveCredentials =
    cfg.credentials
    // (lib.optionalAttrs useGeneratedKey {
      STATIC_API_KEY = generatedApiKeyPath;
    });

  exportCredentials = n: _: ''export ${n}="$(${pkgs.systemd}/bin/systemd-creds cat ${n}_FILE)"'';
  exportAllCredentials = vars: lib.concatStringsSep "\n" (lib.mapAttrsToList exportCredentials vars);
  getLoadCredentialList = lib.mapAttrsToList (n: v: "${n}_FILE:${v}") effectiveCredentials;

  pocket-id-bootstrap = import ./pocket-id-bootstrap.nix pkgs;
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
            # Note: For public clients, this file will not be created.
            default = "${secretsDir}/${config.id}";
            description = "The expected path to the secret file for this client. Use this in other modules.";
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    # Generate a random API Key if one isn't provided in credentials
    systemd.services.pocket-id-key-gen = mkIf useGeneratedKey {
      description = "Generate shared API key for Pocket ID";
      before = ["pocket-id.service" "pocket-id-provisioner.service"];
      requiredBy = ["pocket-id.service" "pocket-id-provisioner.service"];
      serviceConfig = {
        Type = "oneshot";
        RuntimeDirectory = baseNameOf sharedKeyDir; # pocket-id-shared
        RuntimeDirectoryMode = "0700";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "gen-pocket-id-key" ''
          if [ ! -f ${generatedApiKeyPath} ]; then
            ${getExe pkgs.openssl} rand -hex 32 | tr -d '\n' > ${generatedApiKeyPath}
          fi
        '';
      };
    };

    systemd.services.pocket-id = {
      serviceConfig = {
        LoadCredential = getLoadCredentialList;
        ExecStart = lib.mkForce (pkgs.writeShellScript "pocket-id-start" ''
          ${exportAllCredentials effectiveCredentials}
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
        LoadCredential = ["static_api_key:${finalApiKeyPath}"];
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
