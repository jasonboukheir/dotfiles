{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.homelab;
  wk = cfg.wellKnown;
  matrix = wk.matrix;

  jsonReturn = body: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON body}';
  '';

  # `.well-known/matrix/client` carries homeserver discovery, (MSC2965)
  # auth-provider discovery, and (MSC4143) MatrixRTC backend discovery
  # in a single JSON doc, so all three keys are assembled here and
  # emitted together.
  clientWellKnownBody = let
    homeserver =
      if matrix.client != null
      then {"m.homeserver" = {base_url = matrix.client;};}
      else {};
    authentication =
      if matrix.issuer != null
      then {
        "m.authentication" = lib.filterAttrs (_: v: v != null) {
          issuer = matrix.issuer;
          account = matrix.account;
        };
      }
      else {};
    rtcFoci =
      if matrix.rtcFoci != []
      then {"org.matrix.msc4143.rtc_foci" = matrix.rtcFoci;}
      else {};
  in
    homeserver // authentication // rtcFoci;

  # Mirrors the listener pairs in modules/homelab/services.nix. The apex
  # vhost takes both sets so federation peers and off-LAN Matrix clients
  # — arriving via the public 443 → 8443 NAT — can reach
  # `.well-known/matrix/*`. Apex only serves static JSON / redirects, so
  # exposing it externally is bounded.
  internalListeners = [
    {
      addr = "0.0.0.0";
      port = 80;
      ssl = false;
    }
    {
      addr = "[::]";
      port = 80;
      ssl = false;
    }
    {
      addr = "0.0.0.0";
      port = 443;
      ssl = true;
    }
    {
      addr = "[::]";
      port = 443;
      ssl = true;
    }
  ];
  externalListeners = [
    {
      addr = "0.0.0.0";
      port = 8080;
      ssl = false;
    }
    {
      addr = "[::]";
      port = 8080;
      ssl = false;
    }
    {
      addr = "0.0.0.0";
      port = 8443;
      ssl = true;
    }
    {
      addr = "[::]";
      port = 8443;
      ssl = true;
    }
  ];
in {
  options.homelab.wellKnown = {
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
    matrix = {
      server = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "synapse.example.com:443";
        description = ''
          Federation delegation target served at `.well-known/matrix/server`
          as `m.server`. Decouples the user-facing `server_name` (apex)
          from wherever synapse currently listens.
        '';
      };
      client = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://synapse.example.com";
        description = ''
          Client autodiscovery base URL served at `.well-known/matrix/client`
          as `m.homeserver.base_url`.
        '';
      };
      issuer = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://auth.example.com/";
        description = ''
          OIDC issuer URL advertised at `.well-known/matrix/client` as
          `m.authentication.issuer` (MSC2965 / Matrix v1.15). Modern
          clients — Element Web's native OIDC flow, Element X — discover
          the auth provider here instead of `/login`, which under MSC3861
          delegation no longer advertises a usable flow. Trailing slash
          must match the issuer the auth service mints tokens under.
        '';
      };
      account = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://auth.example.com/account";
        description = ''
          Account-management URL served alongside `m.authentication.issuer`.
          Clients open this when the user picks "Account settings" so they
          land at the auth service's account page rather than a Matrix one
          synapse can't honor under delegated auth.
        '';
      };
      rtcFoci = mkOption {
        type = types.listOf (types.attrsOf types.anything);
        default = [];
        example = literalExpression ''
          [{ type = "livekit"; livekit_service_url = "https://matrix-rtc.example.com/livekit/jwt"; }]
        '';
        description = ''
          MatrixRTC focus list advertised at `.well-known/matrix/client`
          as `org.matrix.msc4143.rtc_foci`. Element X / Element Web's
          group-call code reads this to discover the SFU + JWT auth
          backend; without it MatrixRTC silently falls back to a single
          hard-coded public SFU (or refuses to start a call).
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.nginx.virtualHosts.${cfg.domain} = {
      forceSSL = true;
      useACMEHost = cfg.domain;
      listen = internalListeners ++ externalListeners;
      locations = mkMerge [
        (mkIf (wk.caldav != null) {
          "/.well-known/caldav".return = "301 https://${wk.caldav}";
        })
        (mkIf (wk.carddav != null) {
          "/.well-known/carddav".return = "301 https://${wk.carddav}";
        })
        (mkIf (wk.webdav != null) {
          "/remote.php/dav".return = "301 https://${wk.webdav}/remote.php/dav";
        })
        (mkIf (matrix.server != null) {
          "= /.well-known/matrix/server".extraConfig =
            jsonReturn {"m.server" = matrix.server;};
        })
        (mkIf (clientWellKnownBody != {}) {
          "= /.well-known/matrix/client".extraConfig =
            jsonReturn clientWellKnownBody;
        })
      ];
    };
  };
}
