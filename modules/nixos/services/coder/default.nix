{
  config,
  lib,
  pkgs,
  terranix,
  ...
}: let
  inherit (lib) mkOption mkEnableOption mkIf mkMerge mkForce types getExe optionalAttrs optionalString concatStringsSep;
  cfg = config.services.coder;

  credsLib = import ../../lib/credentials.nix {inherit lib;};
  credHelpers = credsLib.mkCredentialsHelpers {inherit cfg pkgs;};

  oidcEnv = optionalAttrs cfg.oidc.enable ({
      CODER_OIDC_ISSUER_URL = cfg.oidc.issuerUrl;
      CODER_OIDC_CLIENT_ID = cfg.oidc.clientId;
      CODER_OIDC_USERNAME_FIELD = cfg.oidc.usernameField;
      CODER_OIDC_SIGN_IN_TEXT = cfg.oidc.signInText;
      CODER_OIDC_ALLOW_SIGNUPS =
        if cfg.oidc.allowSignups
        then "true"
        else "false";
      CODER_OIDC_SCOPES = concatStringsSep "," cfg.oidc.scopes;
    }
    // optionalAttrs (cfg.oidc.emailDomains != []) {
      CODER_OIDC_EMAIL_DOMAIN = concatStringsSep "," cfg.oidc.emailDomains;
    }
    // optionalAttrs (cfg.oidc.iconUrl != null) {
      CODER_OIDC_ICON_URL = cfg.oidc.iconUrl;
    }
    // cfg.oidc.extraEnv);

  templateDirs = lib.mapAttrs (name: tpl: let
    tfJson = terranix.lib.terranixConfiguration {
      system = pkgs.stdenv.hostPlatform.system;
      modules = tpl.modules;
    };
  in
    pkgs.runCommand "coder-template-${name}" {} ''
      mkdir -p $out
      cp ${tfJson} $out/main.tf.json
      ${optionalString (tpl.extraFiles != null) ''
        cp -r ${tpl.extraFiles}/. $out/
      ''}
    '')
  cfg.ensureTemplates;
in {
  options.services.coder = {
    credentials = credsLib.mkCredentialsOption {
      description = ''
        Environment variables loaded from credential files via systemd
        LoadCredential. Used here to inject CODER_OIDC_CLIENT_SECRET (and any
        other secrets) without writing them to disk in the world-readable Nix
        store.
      '';
    };

    oidc = {
      enable = mkEnableOption "OIDC authentication on the Coder server";

      issuerUrl = mkOption {
        type = types.str;
        description = "OIDC issuer URL (the IdP's discovery base, e.g. https://id.example.com).";
      };

      clientId = mkOption {
        type = types.str;
        description = "OIDC client ID registered with the IdP.";
      };

      clientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to a file containing the OIDC client secret. Loaded via systemd
          LoadCredential and exported as CODER_OIDC_CLIENT_SECRET at runtime.
        '';
      };

      emailDomains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Restrict signup to users whose email is in these domains. Empty means no restriction.";
      };

      usernameField = mkOption {
        type = types.str;
        default = "preferred_username";
        description = "OIDC claim used as the Coder username.";
      };

      signInText = mkOption {
        type = types.str;
        default = "Sign in with OIDC";
      };

      iconUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
      };

      allowSignups = mkOption {
        type = types.bool;
        default = true;
        description = "Allow new users to sign up via OIDC on first login.";
      };

      scopes = mkOption {
        type = types.listOf types.str;
        default = ["openid" "profile" "email"];
      };

      extraEnv = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Additional CODER_OIDC_* environment variables.";
      };
    };

    ensureTemplates = mkOption {
      default = {};
      description = ''
        Coder templates rendered declaratively via terranix and staged to
        ${"$"}{homeDir}/templates/<name>/ at activation time. Upload them through
        the Coder web UI ("Templates" → "Create template" → "Upload directory")
        or via `coder templates push <name> --directory <path>`.
      '';
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          modules = mkOption {
            type = types.listOf types.unspecified;
            description = "Terranix modules describing this Coder template.";
          };

          extraFiles = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Optional directory whose contents are copied alongside main.tf.json.";
          };
        };
      }));
    };

    podmanGroup = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        If set, add the coder service user to this group so the Coder server
        can reach the podman docker-compatible socket for container templates.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.coder.environment.extra = mkMerge [oidcEnv];

    services.coder.credentials = mkIf (cfg.oidc.enable && cfg.oidc.clientSecretFile != null) {
      CODER_OIDC_CLIENT_SECRET = cfg.oidc.clientSecretFile;
    };

    systemd.services.coder = {
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        LoadCredential = credHelpers.loadList;
        ExecStart = mkForce (pkgs.writeShellScript "coder-start" ''
          ${credHelpers.exportScript}
          exec ${getExe cfg.package} server
        '');
      };
    };

    users.users.${cfg.user} = mkIf (cfg.podmanGroup != null) {
      extraGroups = [cfg.podmanGroup];
    };

    systemd.tmpfiles.rules = lib.optionals (cfg.ensureTemplates != {}) [
      "d ${cfg.homeDir}/templates 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.coder-templates-stage = mkIf (cfg.ensureTemplates != {}) {
      description = "Stage Coder templates rendered from terranix into ${cfg.homeDir}/templates";
      after = ["coder.service"];
      wants = ["coder.service"];
      wantedBy = ["multi-user.target"];

      path = [pkgs.coreutils];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        RemainAfterExit = true;
      };

      script = let
        copyTemplate = name: dir: ''
          rm -rf ${cfg.homeDir}/templates/${name}
          mkdir -p ${cfg.homeDir}/templates/${name}
          cp -rL ${dir}/. ${cfg.homeDir}/templates/${name}/
          chmod -R u+w ${cfg.homeDir}/templates/${name}
        '';
      in ''
        set -euo pipefail
        ${concatStringsSep "\n" (lib.mapAttrsToList copyTemplate templateDirs)}
      '';
    };
  };
}
