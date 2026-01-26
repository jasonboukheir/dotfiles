{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.services.pocket-id;
  jsonFormat = pkgs.formats.json {};

  pocket-id-bootstrap = pkgs.callPackage ./bootstrap-script.nix {};

  allDependentServices = lib.unique (lib.flatten (lib.mapAttrsToList (
      _: c:
        map (s:
          if lib.hasSuffix ".service" s
          then s
          else "${s}.service")
        c.dependentServices
    )
    cfg.ensureClients));
in {
  options.services.pocket-id = {
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
            default = "${cfg.internal.secretsDir}/${config.settings.id}";
            description = "The expected path to the secret file for this client. Use this in other modules.";
          };
        };
      }));
    };
  };

  config = mkIf (cfg.enable && cfg.ensureClients != {}) (let
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
    systemd.services.pocket-id-provisioner = {
      description = "Provision Pocket ID OIDC Clients";
      after = ["pocket-id.service"];
      wants = ["pocket-id.service"];
      wantedBy = ["multi-user.target"];

      before = allDependentServices;
      requiredBy = allDependentServices;

      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        RuntimeDirectory = baseNameOf cfg.internal.secretsDir;
        LoadCredential = ["static_api_key:${cfg.internal.finalApiKeyPath}"];
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
    };
  });
}
