{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (lib) getExe mkIf mkOption types;
  cfg = config.services.pocket-id;

  # Import the credentials library
  credsLib = import ../../lib/credentials.nix {inherit lib;};

  generatedApiKeyPath = "${cfg.internal.sharedKeyDir}/api_key";

  # Determine if we should use the generated key or a user-provided one
  useGeneratedKey = ! (cfg.credentials ? STATIC_API_KEY);

  # Calculate the final path and expose it for bootstrap.nix
  finalApiKeyPath =
    if useGeneratedKey
    then generatedApiKeyPath
    else cfg.credentials.STATIC_API_KEY;

  # Create a "virtual" config that merges user credentials with the generated key
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
in {
  options.services.pocket-id = {
    credentials = credsLib.mkCredentialsOption {};

    # Internal option to share the resolved key path with bootstrap.nix
    internal.finalApiKeyPath = mkOption {
      type = types.path;
      default = finalApiKeyPath;
      readOnly = true;
      description = "The resolved path to the STATIC_API_KEY.";
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
        RuntimeDirectory = baseNameOf cfg.internal.sharedKeyDir;
        RuntimeDirectoryMode = "0700";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "gen-pocket-id-key" ''
          if [ ! -f ${generatedApiKeyPath} ]; then
            ${getExe pkgs.openssl} rand -hex 32 | tr -d '\n' > ${generatedApiKeyPath}
          fi
        '';
      };
    };

    # Configure the main service with credentials
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
  };
}
