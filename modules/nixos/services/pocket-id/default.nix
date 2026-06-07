{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.pocket-id;
  jsonFormat = pkgs.formats.json {};

  secretsDir = "/run/pocket-id-secrets";
  generatedApiKeyPath = config.ephemeral-secrets.pocket-id-api-key.path;

  # The provisioner authenticates with STATIC_API_KEY. Use the user-provided
  # one if present, otherwise the key generated below via ephemeral-secrets.
  apiKeyPath = cfg.credentials.STATIC_API_KEY or generatedApiKeyPath;

  allDependentServices = lib.unique (lib.flatten (lib.mapAttrsToList (
      _: c:
        map (s:
          if lib.hasSuffix ".service" s
          then s
          else "${s}.service")
        c.dependentServices
    )
    cfg.ensureClients));

  pocket-id-bootstrap = pkgs.callPackage ./bootstrap-script.nix {};
in {
  options.services.pocket-id = {
    generateApiKey = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Generate a random STATIC_API_KEY via ephemeral-secrets and load it into
        the server, so declarative `ensureClients` provisioning can authenticate.
        Set to false to supply your own `services.pocket-id.credentials.STATIC_API_KEY`.
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
        options = {
          logo = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the light mode logo file.";
          };
          darkLogo = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the dark mode logo file.";
          };
          settings = mkOption {
            description = "Settings object passed directly to the Pocket ID API.";
            default = {};
            type = types.submodule {
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
                launchURL = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                };
              };
            };
          };

          dependentServices = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of systemd services (e.g. ['grafana']) that depend on this client. They will be configured to start after provisioning is complete.";
          };

          secretFile = mkOption {
            type = types.path;
            readOnly = true;
            # Resolves to: /run/pocket-id-secrets/<client_id>
            # Note: For public clients, this file will not be created.
            default = "${secretsDir}/${config.settings.id}";
            description = "The expected path to the secret file for this client. Use this in other modules.";
          };
        };
      }));
    };
  };

  config = mkIf cfg.enable {
    # Generate a random API key via ephemeral-secrets and hand it to the server
    # through the upstream credentials mechanism (loaded as STATIC_API_KEY).
    ephemeral-secrets.pocket-id-api-key = mkIf cfg.generateApiKey {};
    services.pocket-id.credentials.STATIC_API_KEY = mkIf cfg.generateApiKey generatedApiKeyPath;

    systemd.services.pocket-id-provisioner = mkIf (cfg.ensureClients != {}) (let
      clientsList =
        lib.mapAttrsToList (
          _: c:
            c.settings
            // {
              logo = c.logo;
              darkLogo = c.darkLogo;
            }
        )
        cfg.ensureClients;
      clientsConfigFile = jsonFormat.generate "pocket-id-clients.json" clientsList;
    in {
      description = "Provision Pocket ID OIDC Clients";
      after = ["pocket-id.service"];
      wants = ["pocket-id.service"];
      wantedBy = ["multi-user.target"];

      before = allDependentServices;
      requiredBy = allDependentServices;

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        RuntimeDirectory = baseNameOf secretsDir;
        LoadCredential = ["static_api_key:${apiKeyPath}"];
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
