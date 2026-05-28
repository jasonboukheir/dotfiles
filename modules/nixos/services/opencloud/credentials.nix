{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.opencloud;
  credCfg = cfg.credentialBootstrap;
  credLib = import ../../lib/credentials.nix {inherit lib;};

  generators = {
    uuid = "${pkgs.util-linux}/bin/uuidgen";
    hex32 = "${pkgs.openssl}/bin/openssl rand -hex 32";
  };
in {
  options.services.opencloud = {
    credentials = credLib.mkCredentialsOption {
      description = ''
        Map of OpenCloud env-var names to source file paths. Wired into the
        opencloud service via systemd LoadCredential and exported in the
        ExecStart wrapper so they override values baked into
        `/etc/opencloud/opencloud.yaml`.

        Set per-key explicitly, or enable `credentialBootstrap` to have the
        module generate files at `<stateDir>/credentials/<NAME>` on first
        boot and wire them in automatically.
      '';
    };

    credentialBootstrap = {
      enable =
        lib.mkEnableOption "auto-generating OpenCloud secrets at boot";

      directory = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.stateDir}/credentials";
        defaultText = lib.literalExpression ''"''${cfg.stateDir}/credentials"'';
        description = "Directory holding bootstrapped credential files.";
      };

      keys = lib.mkOption {
        type = lib.types.attrsOf (lib.types.enum (lib.attrNames generators));
        default = {
          OC_ADMIN_USER_ID = "uuid";
          OC_SYSTEM_USER_ID = "uuid";
          OC_SYSTEM_USER_API_KEY = "hex32";
          OC_SERVICE_ACCOUNT_ID = "uuid";
          OC_SERVICE_ACCOUNT_SECRET = "hex32";
          OC_JWT_SECRET = "hex32";
          OC_MACHINE_AUTH_API_KEY = "hex32";
          OC_TRANSFER_SECRET = "hex32";
          OC_URL_SIGNING_SECRET = "hex32";
          OC_LDAP_BIND_PASSWORD = "hex32";
          OC_EVENTS_AUTH_PASSWORD = "hex32";
          OC_CACHE_AUTH_PASSWORD = "hex32";
          OC_PERSISTENT_STORE_AUTH_PASSWORD = "hex32";
        };
        description = ''
          Map of credential env-var name to generator strategy. For each
          entry, a file at `<directory>/<name>` is created on first boot if
          absent. Existing files are never rewritten, so migration is just
          dropping the previous yaml-derived values in place beforehand and
          letting the unit fill in anything new.

          Supported generators: ${lib.concatStringsSep ", " (lib.attrNames generators)}.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf credCfg.enable {
      services.opencloud.credentials =
        lib.mapAttrs
        (name: _: "${credCfg.directory}/${name}")
        credCfg.keys;

      systemd.tmpfiles.settings."10-opencloud-credentials".${credCfg.directory}.d = {
        inherit (cfg) user group;
        mode = "0700";
      };

      systemd.services.opencloud-credentials-bootstrap = {
        description = "Generate missing OpenCloud secret credentials";
        wantedBy = ["multi-user.target"];
        before = ["opencloud.service" "opencloud-init-config.service"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          ReadWritePaths = [credCfg.directory];
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
        };

        path = [pkgs.coreutils pkgs.util-linux pkgs.openssl];

        script =
          ''
            set -eu
            install -d -m 0700 "${credCfg.directory}"
          ''
          + lib.concatMapStringsSep "\n" (name: let
            gen = credCfg.keys.${name};
            generator = generators.${gen};
          in ''
            f="${credCfg.directory}/${name}"
            if [ ! -s "$f" ]; then
              ${generator} > "$f"
              chmod 0400 "$f"
            fi
          '') (lib.attrNames credCfg.keys);
      };

      systemd.services.opencloud = {
        after = ["opencloud-credentials-bootstrap.service"];
        requires = ["opencloud-credentials-bootstrap.service"];
      };

      systemd.services.opencloud-init-config =
        lib.mkIf ((cfg.settings.opencloud or {}) == {}) {
          script = lib.mkForce ''
            echo "opencloud-init-config neutralized: secrets are managed via services.opencloud.credentials"
          '';
        };
    })

    (lib.mkIf (cfg.credentials != {}) (let
      creds = credLib.mkCredentialsHelpers {inherit cfg pkgs;};
    in {
      systemd.services.opencloud.serviceConfig = {
        LoadCredential = creds.loadList;
        ExecStart = lib.mkForce (pkgs.writeShellScript "opencloud-server-start" ''
          ${creds.exportScript}
          exec ${lib.getExe cfg.package} server
        '');
      };
    }))
  ];
}
