{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.services.libation;
  nixarr = config.nixarr;
  # Audiobooks go to nixarr mediaDir so audiobookshelf can access them
  booksDir = "${nixarr.mediaDir}/library/audiobooks";
  # State directory for config and database
  stateDir = "/var/lib/libation";
in {
  options.services.libation = {
    enable = lib.mkEnableOption "Libation Audible audiobook manager";

    accountsSettingsFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the AccountsSettings.json file containing Audible credentials.
        This is typically managed via agenix and passed as config.age.secrets."...".path.
      '';
      example = lib.literalExpression ''config.age.secrets."libation/AccountsSettings.json".path'';
    };

    settingsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Optional path to a Settings.json file for custom Libation configuration.
        If null, Libation uses its defaults.
      '';
      example = lib.literalExpression ''config.age.secrets."libation/Settings.json".path'';
    };

    sleepTime = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = ''
        Interval in seconds between library scans.
        Set to -1 to run once and exit.
        Default: 3600 (1 hour)
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "libation";
      description = "User account under which Libation runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Group under which Libation runs (should match nixarr media group)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure nixarr is enabled (we depend on its media directory)
    assertions = [
      {
        assertion = nixarr.enable;
        message = "Libation requires nixarr to be enabled for media directory access";
      }
    ];

    # Create libation user with media group for audiobookshelf compatibility
    # Container runs as UID 1001, files need media group for audiobookshelf to read
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      uid = 1001;
      home = stateDir;
      createHome = true;
    };

    # Ensure directories exist with correct permissions
    # setgid (2xxx) on booksDir ensures new files inherit the media group
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/config 0755 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/db 0755 ${cfg.user} ${cfg.group} -"
      "d ${booksDir} 2775 ${cfg.user} ${cfg.group} -"
    ];

    # Copy secrets to config directory before container starts
    systemd.services.libation-config-setup = {
      description = "Set up Libation configuration files";
      wantedBy = ["podman-libation.service"];
      before = ["podman-libation.service"];
      path = [pkgs.coreutils];
      script = ''
        # Copy AccountsSettings.json (required)
        cp "${cfg.accountsSettingsFile}" "${stateDir}/config/AccountsSettings.json"
        chmod 600 "${stateDir}/config/AccountsSettings.json"
        ${lib.optionalString (cfg.settingsFile != null) ''
          # Copy Settings.json (optional custom settings)
          cp "${cfg.settingsFile}" "${stateDir}/config/Settings.json"
          chmod 600 "${stateDir}/config/Settings.json"
        ''}
      '';
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    virtualisation.oci-containers.containers.libation = {
      autoStart = true;
      image = "rmcrackan/libation:latest";

      environment = {
        SLEEP_TIME = toString cfg.sleepTime;
        LIBATION_CONFIG_DIR = "/config";
        LIBATION_BOOKS_DIR = "/data";
        LIBATION_DB_DIR = "/db";
        LIBATION_CREATE_DB = "true";
      };

      volumes = [
        "${stateDir}/config:/config"
        "${stateDir}/db:/db"
        "${booksDir}:/data"
      ];

      # Run as libation user, add media group for audiobookshelf compatibility
      # Use GID directly since podman resolves groups before container start
      user = toString config.users.users.${cfg.user}.uid;
      extraOptions = [
        "--group-add=${toString config.users.groups.${cfg.group}.gid}"
      ];
    };
  };
}
