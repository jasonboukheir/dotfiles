{
  config,
  options,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.matrix-bridges;
  serverName = config.homelab.domain;
  synapsePort = config.homelab.ports.values.matrix-synapse;
  synapseAddress = "http://127.0.0.1:${toString synapsePort}";

  # The mautrix-discord upstream module declares its settings sub-keys
  # (`appservice`, `bridge`, `homeserver`, ...) as `type = lib.types.attrs`
  # *without* an `apply = recursiveUpdate default;` like the other bridges
  # use. That means any user-provided `settings.appservice = { ... }` block
  # replaces the upstream defaults atomically (priority-filter drops the
  # default definition entirely), stripping out keys we don't restate —
  # including `appservice.database`, which the bridge refuses to start
  # without. Pull the defaults from the option tree so we deep-merge
  # explicitly instead of regressing every time upstream adds a key.
  discordDefaults = name:
    (options.services.mautrix-discord.settings.type.getSubOptions [])
    .${name}.default;
  adminMxid = "@${cfg.adminLocalpart}:${serverName}";

  anyEnabled = lib.any (b: b.enable) (lib.attrValues {
    inherit (cfg) discord telegram whatsapp signal gmessages;
  });

  bridgeOpt = name:
    lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "the ${name} mautrix bridge";
        };
      };
      default = {};
    };

  # Olm pickle keys (and the provisioning/media signing secrets when
  # those features are exposed) must stay stable across restarts —
  # every encrypted device session is bound to the key the bridge had
  # when it provisioned it. Upstream's default of `pickle_key = "generate"`
  # works when the bridge owns its config.yaml, but our setup re-renders
  # config.yaml from the store on every preStart so "generate" gets
  # clobbered. The oneshot below mints a per-bridge envfile once; preStart's
  # envsubst then pulls the values into the rendered YAML.
  secretsDirFor = bridge: "/var/lib/mautrix-${bridge}-secrets";
  secretsFileFor = bridge: "${secretsDirFor bridge}/env";

  mkBridgeSecrets = {
    bridge,
    envPrefix,
    # Discord ships a separate `mautrix-discord-registration.service`
    # oneshot that also reads EnvironmentFile= and runs *before* the
    # main bridge — secrets have to land before it, not just before the
    # bridge proper. Other bridges keep registration inline in preStart,
    # so only this list needs the extra unit name.
    extraDeps ? [],
  }: {
    name = "mautrix-${bridge}-secrets";
    value = {
      description = "Generate stable encryption secrets for mautrix-${bridge}";
      before = ["mautrix-${bridge}.service"] ++ extraDeps;
      wantedBy = ["mautrix-${bridge}.service"] ++ extraDeps;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0077";
      };
      path = [pkgs.openssl pkgs.coreutils];
      script = ''
        set -euo pipefail
        install -d -m 0750 -o mautrix-${bridge} -g mautrix-${bridge} ${secretsDirFor bridge}
        if [ ! -s ${secretsFileFor bridge} ]; then
          tmp=$(mktemp ${secretsFileFor bridge}.XXXXXX)
          {
            echo "${envPrefix}_ENCRYPTION_PICKLE_KEY=$(openssl rand -hex 32)"
            echo "${envPrefix}_PROVISIONING_SHARED_SECRET=$(openssl rand -hex 32)"
            echo "${envPrefix}_PUBLIC_MEDIA_SIGNING_KEY=$(openssl rand -hex 32)"
            echo "${envPrefix}_DIRECT_MEDIA_SERVER_KEY=$(openssl rand -hex 32)"
          } > "$tmp"
          chmod 0640 "$tmp"
          chown mautrix-${bridge}:mautrix-${bridge} "$tmp"
          mv "$tmp" ${secretsFileFor bridge}
        fi
      '';
    };
  };

  # Encryption + secret-reference fragments shared by all Go bridges
  # whose upstream module accepts `apply = recursiveUpdate defaultConfig`
  # (whatsapp/signal/gmessages). preStart's envsubst replaces the
  # placeholders with values from the generated EnvironmentFile.
  #
  # Note: the mautrix-go bridges (whatsapp/signal/gmessages) put
  # `encryption` at the *top level* of their YAML — not under `bridge.*`
  # the way the older mautrix-discord codebase does. Mis-nesting here
  # is silent: the bridge happily ignores `bridge.encryption.allow`
  # while leaving the top-level `encryption.allow` at its `false` default,
  # so portals come out unencrypted and decryption fails with "no crypto".
  goBridgeSecretSettings = envPrefix: {
    encryption = {
      allow = true;
      default = true;
      # MSC3202 appservice-mode encryption: the bridge encrypts events
      # as each puppet using a per-puppet device managed via the AS
      # token, instead of having every ghost share the bridge bot's
      # single device. Without this, Element flags every puppet-sent
      # event with "the sender of the event does not match the owner
      # of the device that sent it" — the Megolm session was created
      # by the bot's device but the event sender is the puppet ghost.
      # Requires the matching `msc3202_transaction_extensions` +
      # `msc3983_appservice_otk_claims` + `msc3984_appservice_key_query`
      # flags on synapse (see matrix-synapse/default.nix). Changing
      # this flag rewrites the appservice registration file (the bridge
      # adds `org.matrix.msc3202: true` to it), so you must delete
      # /var/lib/mautrix-<bridge>/<bridge>-registration.yaml and restart
      # both the bridge and synapse the first time you flip it.
      appservice = true;
      # MSC4190 lets the bridge manage its own bot device via the AS
      # token instead of going through /_matrix/client/v3/login.
      # Required here because our synapse delegates auth to MAS via
      # MSC3861 and doesn't serve the legacy /login endpoint at all —
      # the default client-side crypto path hits 404 on startup and
      # the bridge refuses to come up.
      msc4190 = true;
      # Have the bridge bot generate its own cross-signing keys and
      # sign its device with them. Without this, Element renders every
      # bridged message with the "encrypted by a device not verified
      # by its owner" shield: the bridge bot's device is uploaded but
      # never cross-signed, so Element's TOFU heuristics fall back to
      # "untrusted". Safe to enable now that MSC4190 is on (per
      # upstream's note in example-config.yaml, only resetting the
      # bridge db without MSC4190 breaks this).
      self_sign = true;
      pickle_key = "\$${envPrefix}_ENCRYPTION_PICKLE_KEY";
    };
    provisioning.shared_secret = "\$${envPrefix}_PROVISIONING_SHARED_SECRET";
    public_media.signing_key = "\$${envPrefix}_PUBLIC_MEDIA_SIGNING_KEY";
    direct_media.server_key = "\$${envPrefix}_DIRECT_MEDIA_SERVER_KEY";
  };
in {
  imports = [./gmessages.nix];

  options.homelab.matrix-bridges = {
    adminLocalpart = lib.mkOption {
      type = lib.types.str;
      default = "jasonbk";
      description = ''
        Matrix localpart of the user who gets `admin` on every enabled bridge.
        The rest of the homeserver (`*:''${homelab.domain}`) gets `user`;
        outsiders get `relay`.
      '';
    };

    discord = bridgeOpt "Discord";

    telegram = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "the Telegram mautrix bridge";
          # Telegram is the only bridge that needs out-of-band credentials —
          # api_id + api_hash come from my.telegram.org, not from a
          # companion-device pairing flow. agenix-managed envfile per the
          # upstream module's substitution contract.
          environmentFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = ''
              Path to an EnvironmentFile providing
              `MAUTRIX_TELEGRAM_TELEGRAM_API_ID` and
              `MAUTRIX_TELEGRAM_TELEGRAM_API_HASH` (obtain from
              <https://my.telegram.org>).
            '';
          };
        };
      };
      default = {};
    };

    whatsapp = bridgeOpt "WhatsApp";
    signal = bridgeOpt "Signal";
    gmessages = bridgeOpt "Google Messages";
  };

  config = lib.mkMerge [
    (lib.mkIf anyEnabled {
      # mautrix-discord links libolm unconditionally, and the other Go
      # bridges default to it (goolm is upstream-discouraged for prod). We
      # accept the libolm advisory at the bridge tier — synapse itself is
      # MSC3861-delegated and doesn't depend on olm.
      nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16"];
    })

    (lib.mkIf cfg.discord.enable {
      systemd.services = builtins.listToAttrs [
        (mkBridgeSecrets {
          bridge = "discord";
          envPrefix = "MAUTRIX_DISCORD";
          extraDeps = ["mautrix-discord-registration.service"];
        })
      ];
      services.mautrix-discord = {
        enable = true;
        environmentFile = secretsFileFor "discord";
        settings = {
          homeserver =
            discordDefaults "homeserver"
            // {
              address = synapseAddress;
              domain = serverName;
            };
          # Strip the upstream's `as_token`/`hs_token` placeholder
          # strings ("This value is generated when generating the
          # registration") before merging. The discord preStart script
          # uses `yq '.appservice | has("as_token")'` to decide whether
          # to copy the real tokens out of the registration file — if
          # we leave the placeholder strings in place that check returns
          # true and the copy is skipped, leaving the bridge to start
          # with the literal placeholder as its token and fail with
          # "appservice.as_token not configured".
          appservice =
            lib.removeAttrs (discordDefaults "appservice") ["as_token" "hs_token"]
            // {
              hostname = "127.0.0.1";
              address = "http://127.0.0.1:29334";
            };
          bridge = lib.recursiveUpdate (discordDefaults "bridge") {
            permissions = {
              "*" = "relay";
              ${serverName} = "user";
              ${adminMxid} = "admin";
            };
            encryption = {
              allow = true;
              default = true;
              # See goBridgeSecretSettings for the MSC3202 appservice /
              # MSC4190 / self_sign rationale — same applies to
              # mautrix-discord.
              appservice = true;
              msc4190 = true;
              self_sign = true;
              pickle_key = "\$MAUTRIX_DISCORD_ENCRYPTION_PICKLE_KEY";
            };
            provisioning.shared_secret = "\$MAUTRIX_DISCORD_PROVISIONING_SHARED_SECRET";
            direct_media.server_key = "\$MAUTRIX_DISCORD_DIRECT_MEDIA_SERVER_KEY";
          };
        };
      };
    })

    (lib.mkIf cfg.telegram.enable {
      services.mautrix-telegram = {
        enable = true;
        environmentFile = cfg.telegram.environmentFile;
        settings = {
          homeserver = {
            address = synapseAddress;
            domain = serverName;
          };
          appservice = {
            # Upstream default is 8080, which collides with the homelab's
            # nginx HTTP listener. 29335 sits in the same 29xxx band the
            # other mautrix bridges occupy.
            hostname = "127.0.0.1";
            port = 29335;
            address = "http://127.0.0.1:29335";
            # Substituted from the EnvironmentFile at preStart via envsubst.
            # Without the placeholders, the upstream substitution step
            # writes literal `$VAR` strings into the rendered config.
            as_token = "\$MAUTRIX_TELEGRAM_APPSERVICE_AS_TOKEN";
            hs_token = "\$MAUTRIX_TELEGRAM_APPSERVICE_HS_TOKEN";
          };
          telegram = {
            api_id = "\$MAUTRIX_TELEGRAM_TELEGRAM_API_ID";
            api_hash = "\$MAUTRIX_TELEGRAM_TELEGRAM_API_HASH";
          };
          bridge = {
            permissions = {
              "*" = "relaybot";
              ${serverName} = "full";
              ${adminMxid} = "admin";
            };
            # mautrix-telegram is a Python bridge, so encryption lives
            # under `bridge.encryption` (the Go bridges put it at the
            # top level — see [[goBridgeSecretSettings]]). mautrix-python
            # uses a hardcoded pickle key ("mautrix.bridge.e2ee") and
            # keeps Olm state in its DB, so no envfile-managed secret is
            # needed here. See goBridgeSecretSettings for the MSC3202 /
            # MSC4190 rationale (same applies). msc4190 adds
            # `io.element.msc4190: true` to the registration, so when
            # flipping this on the first time you must
            # `rm /var/lib/mautrix-telegram/telegram-registration.yaml`
            # and restart both this bridge and synapse.
            encryption = {
              allow = true;
              default = true;
              appservice = true;
              msc4190 = true;
            };
          };
        };
      };
    })

    (lib.mkIf cfg.whatsapp.enable {
      systemd.services = builtins.listToAttrs [
        (mkBridgeSecrets {
          bridge = "whatsapp";
          envPrefix = "MAUTRIX_WHATSAPP";
        })
      ];
      services.mautrix-whatsapp = {
        enable = true;
        environmentFile = secretsFileFor "whatsapp";
        settings = lib.recursiveUpdate (goBridgeSecretSettings "MAUTRIX_WHATSAPP") {
          homeserver = {
            address = synapseAddress;
            domain = serverName;
          };
          appservice.hostname = "127.0.0.1";
          bridge.permissions = {
            "*" = "relay";
            ${serverName} = "user";
            ${adminMxid} = "admin";
          };
        };
      };
    })

    (lib.mkIf cfg.signal.enable {
      systemd.services = builtins.listToAttrs [
        (mkBridgeSecrets {
          bridge = "signal";
          envPrefix = "MAUTRIX_SIGNAL";
        })
      ];
      services.mautrix-signal = {
        enable = true;
        environmentFile = secretsFileFor "signal";
        settings = lib.recursiveUpdate (goBridgeSecretSettings "MAUTRIX_SIGNAL") {
          homeserver = {
            address = synapseAddress;
            domain = serverName;
          };
          appservice.hostname = "127.0.0.1";
          bridge.permissions = {
            "*" = "relay";
            ${serverName} = "user";
            ${adminMxid} = "admin";
          };
        };
      };
    })
  ];
}
