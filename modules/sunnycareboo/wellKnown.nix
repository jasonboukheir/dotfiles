{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.sunnycareboo;
in {
  options.sunnycareboo.wellKnown = {
    caldav = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Domain of the caldav server.";
    };
    carddav = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Domain of the carddav server.";
    };
    webdav = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Domain of the webdav server.";
    };
  };

  config = mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.baseDomain} = {
      forceSSL = true;
      useACMEHost = cfg.baseDomain;
      locations = {
        "/.well-known/caldav" = mkIf (cfg.wellKnown.caldav != null) {
          return = "301 https://${cfg.wellKnown.caldav}";
        };
        "/.well-known/carddav" = mkIf (cfg.wellKnown.carddav != null) {
          return = "301 https://${cfg.wellKnown.carddav}";
        };
        "/remote.php/dav" = mkIf (cfg.wellKnown.webdav != null) {
          return = "301 https://${cfg.wellKnown.webdav}/remote.php/dav";
        };
      };
    };
  };
}
