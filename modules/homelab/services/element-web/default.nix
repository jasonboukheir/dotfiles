{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.chat;
  serverName = config.homelab.domain;
  synapseDomain = config.homelab.services.synapse.domain;
  callCfg = config.homelab.services.call;

  # nixpkgs's element-web wrapper takes a `conf` arg and merges it onto
  # the upstream config.json — far simpler than overlaying the static
  # tree by hand. Point Element at our homeserver and lock the custom-URL
  # dialog so guests can't accidentally talk to matrix.org.
  elementWeb = pkgs.element-web.override {
    conf =
      {
        default_server_config."m.homeserver" = {
          base_url = "https://${synapseDomain}";
          server_name = serverName;
        };
        brand = "Sunnycareboo Chat";
        # `system` follows the browser's prefers-color-scheme so the
        # client tracks OS-level dark/light flips without a manual
        # toggle in Element's settings.
        default_theme = "system";
        disable_custom_urls = true;
        disable_guests = true;
      }
      // lib.optionalAttrs callCfg.enable {
        # Without this, Element Web embeds `call.element.io` as the
        # group-call widget — which means voice/video traffic flows
        # through someone else's SFU even though our own is wired up.
        # Pointing at the in-cluster SPA keeps the whole media stack
        # on brutus (MSC4143 focus discovery does the SFU lookup).
        element_call = {
          url = "https://${callCfg.domain}";
          participant_limit = 8;
          brand = "Sunnycareboo Call";
        };
        features.feature_video_rooms = true;
        features.feature_group_calls = true;
      };
  };
in {
  config = lib.mkMerge [
    {
      homelab.services.chat = {
        mtls.enable = false;
        # element-web is a static SPA — no backend to proxyPass to. Leaving
        # proxyPass null tells the homelab framework to skip its implicit
        # `/` location so the static-root config below takes over cleanly.
      };
    }
    (lib.mkIf homelabCfg.enable {
      # Compose with the vhost the homelab framework already generates
      # (ACME cert, internal+external listeners, mTLS hooks). NixOS option
      # merging unions both contributors' attrs, so adding `root` + a
      # `/`-location `tryFiles` here doesn't clobber the framework's
      # forceSSL/useACMEHost/listen wiring.
      services.nginx.virtualHosts.${homelabCfg.domain} = {
        root = "${elementWeb}";
        # `$uri/` lets nginx resolve `/mobile_guide` to its directory index;
        # without it the mobile-detect redirect lands on a blank page because
        # try_files falls through to the SPA root, which redirects back.
        # Element Web uses hash routing, so no SPA fallback is needed.
        locations."/".tryFiles = "$uri $uri/ =404";
      };
    })
  ];
}
