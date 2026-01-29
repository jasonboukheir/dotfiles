{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.lldap;

  # --- 1. DEFINE THE MISSING PACKAGE ---
  # Extracted from the patch you provided.
  lldap-bootstrap = pkgs.stdenv.mkDerivation rec {
    meta = {
      mainProgram = "lldap-bootstrap";
    };
    pname = "lldap-bootstrap";
    version = "0.6.2"; # Matches the patch version

    src = pkgs.fetchFromGitHub {
      owner = "lldap";
      repo = "lldap";
      rev = "v${version}";
      hash = "sha256-UBQWOrHika8X24tYdFfY8ETPh9zvI7/HV5j4aK8Uq+Y=";
    };

    dontBuild = true;
    nativeBuildInputs = [pkgs.makeWrapper];

    installPhase = ''
      mkdir -p $out/bin
      cp ./scripts/bootstrap.sh $out/bin/lldap-bootstrap

      wrapProgram $out/bin/lldap-bootstrap \
        --set LLDAP_SET_PASSWORD_PATH ${cfg.package}/bin/lldap_set_password \
        --prefix PATH : ${lib.makeBinPath [pkgs.curl pkgs.jq pkgs.jo]}
    '';
  };

  mkCredName = username: "lldap-user-${username}";

  # --- 2. HELPER FUNCTIONS ---
  # Logic to generate JSON files for users/groups
  ensureFormat = pkgs.formats.json {};

  ensureGenerate = name: source: let
    filterNulls = lib.filterAttrsRecursive (n: v: v != null);
    filteredSource =
      if builtins.isList source
      then map filterNulls source
      else filterNulls source;
  in
    ensureFormat.generate name filteredSource;

  generateEnsureConfigDir = name: source: let
    genOne = name: sourceOne:
      pkgs.writeTextDir "configs/${name}.json" (builtins.readFile (ensureGenerate "configs/${name}.json" sourceOne));
  in "${pkgs.symlinkJoin {
    inherit name;
    paths = lib.mapAttrsToList genOne source;
  }}/configs";

  ensureFieldsOptions = name: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
      };
      attributeType = lib.mkOption {type = lib.types.enum ["STRING" "INTEGER" "JPEG" "DATE_TIME"];};
      isEditable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      isList = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      isVisible = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };
  };
in {
  # --- 3. DEFINE THE NEW OPTIONS ---
  options.services.lldap = with lib; {
    # We add the options that are missing from the upstream module
    ensureUsers = mkOption {
      default = {};
      description = "Declarative user management.";
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = ensureFormat.type;
        options = {
          id = mkOption {
            type = types.str;
            default = name;
          };
          email = mkOption {type = types.str;};
          password_file = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          groups = mkOption {
            type = types.listOf types.str;
            default = [];
          };
          displayName = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          # Add other fields (firstName, lastName, etc) here if needed,
          # or rely on freeformType to pass them through.
        };
      }));
    };

    ensureGroups = mkOption {
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = ensureFormat.type;
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };
        };
      }));
    };

    ensureUserFields = mkOption {
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {options = ensureFieldsOptions name;}));
    };

    ensureGroupFields = mkOption {
      default = {};
      type = types.attrsOf (types.submodule ({name, ...}: {options = ensureFieldsOptions name;}));
    };

    enforceUsers = mkOption {
      type = types.bool;
      default = false;
    };
    enforceUserMemberships = mkOption {
      type = types.bool;
      default = false;
    };
    enforceGroups = mkOption {
      type = types.bool;
      default = false;
    };

    defaultGroups = mkOption {
      default = {
        "lldap_admin" = {name = "lldap_admin";};
        "lldap_password_manager" = {name = "lldap_password_manager";};
        "lldap_strict_readonly" = {name = "lldap_strict_readonly";};
      };
      readOnly = true;
      description = "reference for default groups that are always created in lldap";
      type = types.attrsOf (types.submodule ({name, ...}: {
        freeformType = ensureFormat.type;
        options = {
          name = mkOption {
            type = types.str;
            default = name;
          };
        };
      }));
    };
  };

  # --- 4. IMPLEMENTATION ---
  config = lib.mkIf cfg.enable {
    # Hook into the existing service
    systemd.services.lldap = let
      # 1. Create the list of credentials to load
      # Format: "credName:/path/to/source"
      userCredentials =
        lib.mapAttrsToList (
          name: user:
            if user.password_file != null
            then "${mkCredName name}:${user.password_file}"
            else null
        )
        cfg.ensureUsers;

      # 2. Create the "Runtime" version of the users config
      # This swaps the file path with the path where systemd will mount the secret
      runtimeUsers =
        lib.mapAttrs (
          name: user:
            if user.password_file != null
            then user // {password_file = "/run/credentials/lldap.service/${mkCredName name}";}
            else user
        )
        cfg.ensureUsers;
    in {
      serviceConfig.LoadCredential = lib.filter (x: x != null) userCredentials;

      # Add the bootstrap package to the path if needed, though we wrapped it above.
      path = [lldap-bootstrap];

      # We use mkAfter to ensure this runs AFTER the main service start logic (if any)
      # Note: lldap usually starts immediately, so postStart runs in parallel/after the main PID.
      postStart = lib.mkAfter ''
        # Wait for HTTP port to be open (simple check)
        until ${pkgs.curl}/bin/curl -s -o /dev/null http://127.0.0.1:${toString cfg.settings.http_port}; do
          echo "Waiting for LLDAP to start..."
          sleep 1
        done

        export LLDAP_URL=http://127.0.0.1:${toString cfg.settings.http_port}
        export LLDAP_ADMIN_USERNAME=${cfg.settings.ldap_user_dn}
        export LLDAP_ADMIN_PASSWORD_FILE=${cfg.environment.LLDAP_LDAP_USER_PASS_FILE}

        export USER_CONFIGS_DIR=${generateEnsureConfigDir "users" runtimeUsers}
        export GROUP_CONFIGS_DIR=${generateEnsureConfigDir "groups" cfg.ensureGroups}
        export USER_SCHEMAS_DIR=${generateEnsureConfigDir "userFields" (lib.mapAttrs (n: v: [v]) cfg.ensureUserFields)}
        export GROUP_SCHEMAS_DIR=${generateEnsureConfigDir "groupFields" (lib.mapAttrs (n: v: [v]) cfg.ensureGroupFields)}

        export DO_CLEANUP_USERS=${
          if cfg.enforceUsers
          then "true"
          else "false"
        }
        export DO_CLEANUP_USER_MEMBERSHIPS=${
          if cfg.enforceUserMemberships
          then "true"
          else "false"
        }
        export DO_CLEANUP_GROUPS=${
          if cfg.enforceGroups
          then "true"
          else "false"
        }

        echo "Running LLDAP Bootstrap..."
        ${lib.getExe lldap-bootstrap}
      '';
    };
  };
}
