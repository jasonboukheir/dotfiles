{
  config,
  lib,
  pkgs,
  ...
}: let
  # Import your library.
  credentialsLib = import ../lib/credentials.nix {inherit lib;};

  cfg = config.services.mealie;

  # Create the helpers using the config and pkgs
  helpers = credentialsLib.mkCredentialsHelpers {
    inherit cfg pkgs;
  };
in {
  options.services.mealie = {
    credentials = credentialsLib.mkCredentialsOption {
      description = "Credentials for Mealie (e.g. POSTGRES_PASSWORD, OIDC_CLIENT_SECRET).";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.credentials != {}) {
    systemd.services.mealie = {
      serviceConfig = {
        # 1. Tell systemd to load the files into /run/credentials/mealie.service/
        LoadCredential = helpers.loadList;

        # 2. Override ExecStart to export credentials before starting Mealie
        # Mealie doesn't support _FILE suffixes, so we must inject them as env vars.
        ExecStart = lib.mkForce (pkgs.writeShellScript "mealie-start" ''
          # Export credentials from systemd-creds
          ${helpers.exportScript}

          # Start Mealie (reproducing the command from the upstream module)
          exec ${lib.getExe cfg.package} \
            -b ${cfg.listenAddress}:${toString cfg.port} \
            ${lib.escapeShellArgs cfg.extraOptions}
        '');
      };
    };
  };
}
