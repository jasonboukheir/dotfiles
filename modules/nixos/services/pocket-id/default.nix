{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) getExe mkIf mkOption types;
  cfg = config.services.pocket-id;
  jsonFormat = pkgs.formats.json {};

  # Import the credentials library
  credsLib = import ../../lib/credentials.nix {inherit lib;};

  secretsDir = "/run/pocket-id-secrets";
  generatedApiKeyPath = config.ephemeral-secrets.pocket-id-api-key.path;

  # Determine if we should use the generated key or a user-provided one
  useGeneratedKey = ! (cfg.credentials ? STATIC_API_KEY);
  finalApiKeyPath =
    if useGeneratedKey
    then generatedApiKeyPath
    else cfg.credentials.STATIC_API_KEY;

  # Create a "virtual" config that merges user credentials with the generated key
  # This allows us to pass the complete set to mkCredentialsHelpers
  effectiveConfig =
    cfg
    // {
      credentials =
        cfg.credentials
        // (lib.optionalAttrs useGeneratedKey {
          STATIC_API_KEY = generatedApiKeyPath;
        });
    };

  # Generate the helpers using the effective config
  credHelpers = credsLib.mkCredentialsHelpers {
    cfg = effectiveConfig;
    inherit pkgs;
  };

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
    # Use the helper to define the option
    credentials = credsLib.mkCredentialsOption {};

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
    # Generate a random API key via ephemeral-secrets if one isn't provided
    ephemeral-secrets.pocket-id-api-key = mkIf useGeneratedKey {};

    systemd.services.pocket-id = {
      serviceConfig = {
        # Use the generated load list
        LoadCredential = credHelpers.loadList;
        ExecStart = lib.mkForce (pkgs.writeShellScript "pocket-id-start" ''
          # Use the generated export script
          ${credHelpers.exportScript}
          exec ${getExe cfg.package}
        '');
      };
    };

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
