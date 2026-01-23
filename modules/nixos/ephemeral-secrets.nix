{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.ephemeral-secrets;
in {
  options.ephemeral-secrets = mkOption {
    description = "Map of ephemeral secrets to generate.";
    default = {};
    type = types.attrsOf (types.submodule ({name, ...}: {
      options = {
        user = mkOption {
          type = types.str;
          default = "root";
        };
        group = mkOption {
          type = types.str;
          default = "root";
        };
        mode = mkOption {
          type = types.str;
          default = "0400";
        };
        length = mkOption {
          type = types.int;
          default = 32;
        };

        path = mkOption {
          type = types.path;
          readOnly = true;
          description = "The stable path (e.g. /run/ephemeral-secrets/db_pass)";
        };
      };

      # Set the path directly to the target location
      config.path = "/run/ephemeral-secrets/${name}";
    }));
  };

  config = mkIf (cfg != {}) {
    system.activationScripts.ephemeralSecrets = {
      deps = ["users" "groups"];
      text = let
        mkSecretScript = name: opts: ''
          FILE="${opts.path}"

          # 1. Check if the file exists. If NOT, generate it.
          if [ ! -f "$FILE" ]; then
            echo "Generating ephemeral secret: ${name}"
            ${pkgs.openssl}/bin/openssl rand -base64 ${toString opts.length} > "$FILE"
          fi

          # 2. Always enforce permissions/ownership on every activation.
          # This allows you to change user/mode in Nix without regenerating the secret content.
          chown ${opts.user}:${opts.group} "$FILE"
          chmod ${opts.mode} "$FILE"
        '';
      in ''
        # Ensure the parent directory exists
        mkdir -p /run/ephemeral-secrets
        chmod 755 /run/ephemeral-secrets

        # Run checks and generation for all secrets
        ${concatStringsSep "\n" (mapAttrsToList mkSecretScript cfg)}
      '';
    };
  };
}
