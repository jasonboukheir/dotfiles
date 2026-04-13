{config, ...}: let
  smtpCfg = config.sunnycareboo.smtp;
in {
  age.secrets."smtp/password".file = ../secrets/smtp/password.age;

  sunnycareboo.smtp = {
    host = "smtp.protonmail.ch";
    port = 587;
    from = "noreply@sunnycareboo.com";
    username = "noreply@sunnycareboo.com";
    passwordFile = config.age.secrets."smtp/password".path;
  };

  programs.msmtp = {
    enable = true;
    setSendmail = true;
    defaults = {
      auth = true;
      tls = true;
      tls_starttls = true;
    };
    accounts.default = {
      host = smtpCfg.host;
      port = smtpCfg.port;
      from = smtpCfg.from;
      user = smtpCfg.username;
      passwordeval = "cat ${smtpCfg.passwordFile}";
    };
  };
}
