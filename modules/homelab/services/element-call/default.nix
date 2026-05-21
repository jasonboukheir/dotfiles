{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.call;
  serverName = config.homelab.domain;
  synapseDomain = config.homelab.services.synapse.domain;

  # element-call's nixpkgs derivation ships the built SPA as-is — no
  # `override { conf }` wrapper like element-web has — so we sit a thin
  # wrapper on top that drops a `public/config.json` next to the symlinked
  # tree. Element Web embeds this SPA in an iframe widget, the SPA reads
  # `/config.json` on load to know which homeserver to surface and where
  # to find the MatrixRTC backend (the latter actually comes from
  # `.well-known/matrix/client` at runtime, but pinning the homeserver
  # here keeps standalone-mode joins from prompting for a server URL).
  conf = {
    default_server_config."m.homeserver" = {
      base_url = "https://${synapseDomain}";
      server_name = serverName;
    };
    features.feature_use_device_session_member_events = true;
  };

  elementCall =
    pkgs.runCommand "element-call-wrapped" {
      inherit (pkgs.element-call) version;
      passthru = {inherit conf;};
    } ''
      mkdir -p $out
      cp -r ${pkgs.element-call}/* $out/
      chmod u+w $out
      cat > $out/config.json <<EOF
      ${builtins.toJSON conf}
      EOF
    '';
in {
  config = lib.mkMerge [
    {
      homelab.services.call = {
        isExternal = true;
        mtls.enable = false;
        # element-call is a static SPA — no backend to proxyPass to.
        # Leaving this null skips the framework's implicit `/` location
        # so the root + tryFiles below take effect cleanly.
      };
    }
    (lib.mkIf homelabCfg.enable {
      services.nginx.virtualHosts.${homelabCfg.domain} = {
        root = "${elementCall}";
        # Element Call uses client-side (history-mode) routing under the
        # SPA shell, so any unknown path needs to fall back to
        # `/index.html` for the JS router to take over — otherwise direct
        # links into `/room/...` 404 at the server before the SPA loads.
        locations."/".tryFiles = "$uri $uri/ /index.html";
      };
    })
  ];
}
