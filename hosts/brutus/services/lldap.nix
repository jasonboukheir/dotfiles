{
  config,
  lib,
  ...
}: let
  cfg = config.services.lldap;
in {
  services.lldap = {
    enable = config.services.brutus.enable;
    settings = {
      ldap_base_dn = "dc=sunnycareboo,dc=com";

      ldap_host = "127.0.0.1";
      ldap_port = 3890;

      http_host = "127.0.0.1";
      http_port = 17170;

      http_url = "https://${config.sunnycareboo.services.lldap.domain}";

      jwt_secret_file = null; # these are set with credentials

      force_ldap_user_pass_reset = "always";
      ldap_user_pass_file = null; # these are set with credentials
      ldap_user_email = "admin@sunnycareboo.com";
      ldap_user_dn = "admin";
    };
    environment = {
      LLDAP_LDAP_USER_PASS_FILE = "/run/credentials/lldap.service/ldap_pass";
      LLDAP_JWT_SECRET_FILE = "/run/credentials/lldap.service/jwt_secret";
    };
  };

  age.secrets = lib.mkIf cfg.enable {
    "lldap/admin_password" = {
      file = ../secrets/lldap/admin_password.age;
    };
    "lldap/jwt_secret" = {
      file = ../secrets/lldap/jwt_secret.age;
    };
  };

  systemd.services.lldap.serviceConfig = lib.mkIf cfg.enable {
    LoadCredential = [
      "ldap_pass:${config.age.secrets."lldap/admin_password".path}"
      "jwt_secret:${config.age.secrets."lldap/jwt_secret".path}"
    ];
  };

  sunnycareboo.services.lldap = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://127.0.0.1:${toString cfg.settings.http_port}";
  };
}
