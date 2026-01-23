{
  config,
  lib,
  ...
}: let
  cfg = config.services.radicale;
  ldapCfg = config.services.lldap;
in {
  services.radicale = lib.mkIf config.services.brutus.enable {
    enable = true;
    settings = {
      server = {
        hosts = [
          "0.0.0.0:${toString cfg.port}"
          "[::]:${toString cfg.port}"
        ];
      };
      auth = {
        type = "ldap";
        ldap_uri = "ldap://${ldapCfg.settings.ldap_host}:${toString ldapCfg.settings.ldap_port}";
        ldap_base = ldapCfg.settings.ldap_base_dn;
        ldap_filter = "(uid={0})";
        ldap_reader_dn = "uid=${ldapCfg.ensureUsers.radicale.id},ou=people,${ldapCfg.settings.ldap_base_dn}";
        ldap_secret_file = config.ephemeral-secrets."radicale.ldap.pw".path;
      };
      storage = {
        filesystem_folder = "/var/lib/radicale/collections";
        predefined_collections = builtins.toJSON {
          "def-addressbook" = {
            "D:displayname" = "Personal Address Book";
            tag = "VADDRESSBOOK";
          };
          "def-calendar" = {
            "C:supported-calendar-component-set" = "VEVENT,VJOURNAL,VTODO";
            "D:displayname" = "Personal Calendar";
            tag = "VCALENDAR";
          };
        };
      };
    };
  };

  ephemeral-secrets."radicale.ldap.pw" = lib.mkIf cfg.enable {
    user = "radicale";
    group = "radicale";
  };

  services.lldap = lib.mkIf cfg.enable {
    ensureUsers = {
      radicale = {
        displayName = "radicale";
        email = "radicale@sunnycareboo.com";
        password_file = config.ephemeral-secrets."radicale.ldap.pw".path;
        groups = [
          ldapCfg.defaultGroups."lldap_strict_readonly".name
        ];
      };
    };
  };

  sunnycareboo.services.radicale = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://127.0.0.1:${toString cfg.port}";
  };
}
