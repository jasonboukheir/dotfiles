{
  lib,
  config,
  ...
}: let
  port = 1411;
  domain = config.sunnycareboo.services.id.domain;
  smtpCfg = config.sunnycareboo.smtp;
  lldapCfg = config.services.lldap;
in {
  sunnycareboo.services.id = lib.mkIf config.services.pocket-id.enable {
    enable = true;
    proxyPass = "http://localhost:${toString port}";
    isExternal = true;
    mtls.enable = false;
    extraConfig = ''
      proxy_busy_buffers_size   512k;
      proxy_buffers   4 512k;
      proxy_buffer_size   256k;
    '';
  };
  age.secrets = {
    "pocket-id/encryptionKey" = {
      file = ../secrets/pocket-id/encryptionKey.age;
    };
  };
  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.age.secrets."pocket-id/encryptionKey".path;
      SMTP_PASSWORD = smtpCfg.passwordFile;
      # LDAP_BIND_PASSWORD = config.age.secrets."lldap/admin".path;
    };
    settings = {
      APP_URL = "https://${domain}";
      TRUST_PROXY = true;
      LOG_JSON = true;
      PORT = port;

      SMTP_HOST = smtpCfg.host;
      SMTP_PORT = smtpCfg.port;
      SMTP_FROM = smtpCfg.from;
      SMTP_USER = smtpCfg.username;
      SMTP_TLS = "starttls";

      EMAIL_LOGIN_NOTIFICATION_ENABLED = true;
      EMAIL_ONE_TIME_ACCESS_AS_ADMIN_ENABLED = true;
      EMAIL_VERIFICATION_ENABLED = true;

      UI_CONFIG_DISABLED = true;

      # LDAP_ENABLED = true;
      # LDAP_URL = "ldap://${lldapCfg.settings.ldap_host}:${toString lldapCfg.settings.ldap_port}";
      # LDAP_BIND_DN = "cn=${lldapCfg.settings.ldap_user_dn},ou=people,${lldapCfg.settings.ldap_base_dn}";
      # LDAP_BASE = lldapCfg.settings.ldap_base_dn;

      # LDAP_ATTRIBUTE_USER_UNIQUE_IDENTIFIER = "uuid";
      # LDAP_ATTRIBUTE_USER_USERNAME = "uid";
      # LDAP_ATTRIBUTE_USER_EMAIL = "mail";
      # LDAP_ATTRIBUTE_USER_FIRST_NAME = "givenname";
      # LDAP_ATTRIBUTE_USER_LAST_NAME = "sn";
      # LDAP_ATTRIBUTE_USER_PROFILE_PICTURE = "avatar";
      # LDAP_ATTRIBUTE_GROUP_MEMBER = "member";
      # LDAP_ATTRIBUTE_GROUP_UNIQUE_IDENTIFIER = "uuid";
      # LDAP_ATTRIBUTE_GROUP_NAME = "cn";
      # LDAP_ADMIN_GROUP_NAME = "pocket_id_admin";
    };
  };
}
