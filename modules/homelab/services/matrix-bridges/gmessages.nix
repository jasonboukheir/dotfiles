{
  config,
  lib,
  pkgs,
  ...
}: let
  bridgeCfg = config.homelab.matrix-bridges.gmessages;
  serverName = config.homelab.domain;
  synapsePort = config.homelab.ports.values.matrix-synapse;
  adminLocalpart = config.homelab.matrix-bridges.adminLocalpart;

  dataDir = "/var/lib/mautrix-gmessages";
  secretsDir = "/var/lib/mautrix-gmessages-secrets";
  secretsFile = "${secretsDir}/env";
  registrationFile = "${dataDir}/gmessages-registration.yaml";
  settingsFile = "${dataDir}/config.yaml";

  yamlFormat = pkgs.formats.yaml {};
  # Upstream has no `--generate-example-config` style schema we can reuse,
  # so we hand-author the minimum set of keys the bridge actually reads.
  # Everything else in the rendered config (network/* and bridge/* knobs)
  # is left to the bridge's compiled-in defaults via the `--no-update`-less
  # behavior on first start: mautrix-gmessages backfills missing keys from
  # its example config, so the rendered file converges to a complete one.
  settings = {
    homeserver = {
      address = "http://127.0.0.1:${toString synapsePort}";
      domain = serverName;
      software = "standard";
    };
    appservice = {
      address = "http://127.0.0.1:29336";
      hostname = "127.0.0.1";
      port = 29336;
      id = "gmessages";
      bot = {
        username = "gmessagesbot";
        displayname = "Google Messages bridge bot";
      };
      ephemeral_events = true;
      as_token = "";
      hs_token = "";
      username_template = "gmessages_{{.}}";
    };
    database = {
      type = "sqlite3-fk-wal";
      uri = "file:${dataDir}/mautrix-gmessages.db?_txlock=immediate";
    };
    bridge = {
      command_prefix = "!gm";
      permissions = {
        "*" = "relay";
        ${serverName} = "user";
        "@${adminLocalpart}:${serverName}" = "admin";
      };
    };
    # mautrix-gmessages keeps `encryption` at the top level of its YAML
    # (same shape as mautrix-whatsapp / mautrix-signal). See the matching
    # comment in matrix-bridges/default.nix for the MSC3202 appservice /
    # MSC4190 / self_sign rationale.
    encryption = {
      allow = true;
      default = true;
      appservice = true;
      msc4190 = true;
      self_sign = true;
      pickle_key = "\$MAUTRIX_GMESSAGES_ENCRYPTION_PICKLE_KEY";
    };
    provisioning.shared_secret = "\$MAUTRIX_GMESSAGES_PROVISIONING_SHARED_SECRET";
    public_media.signing_key = "\$MAUTRIX_GMESSAGES_PUBLIC_MEDIA_SIGNING_KEY";
    direct_media.server_key = "\$MAUTRIX_GMESSAGES_DIRECT_MEDIA_SERVER_KEY";
    logging = {
      min_level = "info";
      writers = lib.singleton {
        type = "stdout";
        format = "pretty-colored";
        time_format = " ";
      };
    };
  };
  settingsFileUnsubstituted = yamlFormat.generate "mautrix-gmessages-config.yaml" settings;
in {
  config = lib.mkIf bridgeCfg.enable {
    users.users.mautrix-gmessages = {
      isSystemUser = true;
      group = "mautrix-gmessages";
      home = dataDir;
      description = "Mautrix-Google Messages bridge user";
    };
    users.groups.mautrix-gmessages = {};

    services.matrix-synapse = {
      settings.app_service_config_files = [registrationFile];
    };
    systemd.services.matrix-synapse.serviceConfig.SupplementaryGroups = ["mautrix-gmessages"];

    systemd.services.mautrix-gmessages-secrets = {
      description = "Generate stable encryption secrets for mautrix-gmessages";
      before = ["mautrix-gmessages.service"];
      wantedBy = ["mautrix-gmessages.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      path = [pkgs.openssl pkgs.coreutils];
      script = ''
        set -euo pipefail
        install -d -m 0750 -o mautrix-gmessages -g mautrix-gmessages ${secretsDir}
        if [ ! -s ${secretsFile} ]; then
          tmp=$(mktemp ${secretsFile}.XXXXXX)
          {
            echo "MAUTRIX_GMESSAGES_ENCRYPTION_PICKLE_KEY=$(openssl rand -hex 32)"
            echo "MAUTRIX_GMESSAGES_PROVISIONING_SHARED_SECRET=$(openssl rand -hex 32)"
            echo "MAUTRIX_GMESSAGES_PUBLIC_MEDIA_SIGNING_KEY=$(openssl rand -hex 32)"
            echo "MAUTRIX_GMESSAGES_DIRECT_MEDIA_SERVER_KEY=$(openssl rand -hex 32)"
          } > "$tmp"
          chmod 0640 "$tmp"
          chown mautrix-gmessages:mautrix-gmessages "$tmp"
          mv "$tmp" ${secretsFile}
        fi
      '';
    };

    systemd.services.mautrix-gmessages = {
      description = "mautrix-gmessages, a Matrix-Google Messages puppeting bridge";

      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"] ++ lib.optional config.services.matrix-synapse.enable "matrix-synapse.service";
      after = ["network-online.target"] ++ lib.optional config.services.matrix-synapse.enable "matrix-synapse.service";
      path = [pkgs.ffmpeg-headless];

      preStart = ''
        # Replace the config from the store with a fresh copy each boot so
        # nix-level changes always win, then envsubst the secrets from
        # the oneshot's envfile (encryption pickle key etc.) on top.
        rm -f '${settingsFile}'
        umask 0177
        ${pkgs.envsubst}/bin/envsubst \
          -o '${settingsFile}' \
          -i '${settingsFileUnsubstituted}'

        if [ ! -f '${registrationFile}' ]; then
          ${lib.getExe pkgs.mautrix-gmessages} \
            --generate-registration \
            --config='${settingsFile}' \
            --registration='${registrationFile}'
        fi
        chmod 640 '${registrationFile}'

        # The registration file is the source of truth for the AS/HS
        # tokens; copy them into config.yaml so the bridge presents the
        # same as_token synapse expects on every transaction.
        ${pkgs.yq}/bin/yq -sY '.[0].appservice.as_token = .[1].as_token
          | .[0].appservice.hs_token = .[1].hs_token
          | .[0]' \
          '${settingsFile}' '${registrationFile}' > '${settingsFile}.tmp'
        mv '${settingsFile}.tmp' '${settingsFile}'
      '';

      serviceConfig = {
        Type = "simple";
        User = "mautrix-gmessages";
        Group = "mautrix-gmessages";
        StateDirectory = baseNameOf dataDir;
        WorkingDirectory = dataDir;
        ExecStart = "${lib.getExe pkgs.mautrix-gmessages} --config='${settingsFile}' --registration='${registrationFile}'";
        EnvironmentFile = secretsFile;
        Restart = "on-failure";
        RestartSec = "30s";
        UMask = "0027";

        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = ["@system-service"];
      };

      restartTriggers = [settingsFileUnsubstituted];
    };
  };
}
