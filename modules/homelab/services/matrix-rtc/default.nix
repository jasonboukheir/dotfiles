{
  config,
  lib,
  pkgs,
  ...
}: let
  homelabCfg = config.homelab.services.matrix-rtc;
  domain = homelabCfg.domain;
  livekitPort = config.homelab.ports.values.matrix-rtc-sfu;
  jwtPort = config.homelab.ports.values.matrix-rtc-jwt;

  # LiveKit and lk-jwt-service share one keyfile: LiveKit accepts API
  # calls signed with any key listed in it; lk-jwt-service signs the
  # short-lived join JWTs Element Call hands the SFU using the same
  # `<keyname>: <secret>` pair. Keep the file in a shared dir both
  # units LoadCredential from, so neither service ever reads under the
  # other's sandbox.
  sharedDir = "/var/lib/matrix-rtc-shared";
  keyFile = "${sharedDir}/livekit.key";
  keyName = "matrix-rtc";

  # The path-routed public URL the SFU's WebSocket lives at — also the
  # value Element Call clients are told to connect to via
  # `org.matrix.msc4143.rtc_foci`. lk-jwt-service embeds it as the `url`
  # claim in every JWT it issues, so it must match what nginx exposes
  # (trailing /rtc gets appended by clients).
  sfuWsUrl = "wss://${domain}/livekit/sfu";
in {
  imports = [./turn.nix];

  config = lib.mkMerge [
    {
      homelab.services.matrix-rtc = {
        # Element X mobile + Element Web in arbitrary browsers reach
        # the SFU/JWT endpoints without a homelab client cert. The
        # framework's `isExternal → mtls.enable` default would 403 them.
        mtls.enable = false;
        # No `/` proxyPass: nothing serves the vhost root, and the
        # two MatrixRTC endpoints route by path below.
        locations = {
          # `^~` so nginx prefers these exact prefixes over any regex
          # location that might appear later. Trailing `/` on both the
          # path and proxyPass strip the prefix before forwarding —
          # LiveKit's WS handler lives at `/rtc` and lk-jwt-service
          # mounts its API at `/`.
          "^~ /livekit/sfu/" = {
            proxyPass = "http://127.0.0.1:${toString livekitPort}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_send_timeout 120s;
              proxy_read_timeout 120s;
              proxy_buffering off;
            '';
          };
          "^~ /livekit/jwt/" = {
            proxyPass = "http://127.0.0.1:${toString jwtPort}/";
            proxyWebsockets = false;
          };
        };
      };
    }
    (lib.mkIf homelabCfg.enable {
      homelab.ports.allocate.matrix-rtc-sfu = "auto";
      homelab.ports.allocate.matrix-rtc-jwt = "auto";

      # Generate the shared LiveKit keyfile once, then leave it alone —
      # rotating the secret invalidates every JWT lk-jwt-service has
      # issued, so currently-active calls would drop until clients
      # re-pair. The format is the one-line `<keyname>: <secret>` that
      # both the LiveKit SFU and lk-jwt-service consume verbatim.
      systemd.services.matrix-rtc-secrets = {
        description = "Generate shared LiveKit keyfile for MatrixRTC";
        before = [
          "livekit.service"
          "lk-jwt-service.service"
        ];
        wantedBy = [
          "livekit.service"
          "lk-jwt-service.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          UMask = "0077";
        };
        path = [pkgs.openssl pkgs.coreutils];
        script = ''
          set -euo pipefail
          install -d -m 0750 -o root -g root ${sharedDir}
          if [ ! -s ${keyFile} ]; then
            # 32 random bytes → 43 chars base64url (translated, not
            # stripped, so length stays deterministic — stripping
            # `+/` like the earlier draft did chopped variable bytes
            # off the secret and the keyfile came up short).
            secret=$(openssl rand -base64 32 | tr -d '\n=' | tr '+/' '-_')
            tmp=$(mktemp ${keyFile}.XXXXXX)
            printf '%s: %s\n' "${keyName}" "$secret" > "$tmp"
            chmod 0640 "$tmp"
            mv "$tmp" ${keyFile}
          fi
        '';
      };

      services.livekit = {
        enable = true;
        inherit keyFile;
        settings = {
          port = livekitPort;
          # WS signaling sits behind nginx on the same host — binding
          # the wider listener publicly would let anyone bypass the
          # path-routing vhost and hit the SFU directly without a JWT.
          bind_addresses = ["127.0.0.1"];
          rtc = {
            # WebRTC media flows directly UDP from each participant to
            # the SFU on these ports; nginx is *not* in the media path.
            # The router must DNAT this UDP range to brutus or remote
            # clients will only establish signaling and drop at media.
            port_range_start = 50000;
            port_range_end = 50100;
            # Brutus sits behind a residential NAT and LiveKit has to
            # advertise an externally-reachable IP in its ICE candidates
            # — without this, remote browsers see only the RFC1918 IP
            # and the media leg never connects. STUN discovery here
            # avoids hard-coding a public IP that changes on ISP renew.
            use_external_ip = true;
            # LiveKit's default ICE candidate gathering walks every
            # interface on the host. On brutus that meant podman
            # veths, the wireguard bridge, a USB-ethernet adapter with
            # a link-local 169.254.* address, and the SFU dutifully
            # advertised every one of them to remote clients. iOS
            # Safari/WKWebView (Element X mobile's WebRTC stack)
            # chews through the candidate list slowly and bails before
            # finding the public IP. Pin to eno1 so the only host
            # candidates clients see are the public 50.47.214.120 (via
            # `use_external_ip` + STUN) and the LAN 192.168.50.182.
            interfaces.includes = ["eno1"];
            # Pin LiveKit's TCP-fallback ICE port so the router DNAT
            # for 7881 keeps working across rebuilds. Without this,
            # LiveKit picks the default at boot (currently 7881) but
            # nothing in the schema forbids a future bump.
            tcp_port = 7881;
          };
        };
        # The SFU does the firewall hole itself for the RTC range so the
        # forwarded UDP ports actually reach the daemon. The TCP
        # signaling port stays loopback-only above and nginx handles
        # the public side on 443/8443.
        openFirewall = true;
      };

      # The upstream livekit module's `openFirewall` opens the UDP RTC
      # range and the WS signaling port (loopback-only here, so a
      # no-op for ingress) but skips the TCP fallback port. Open it
      # explicitly so router DNAT for 7881 reaches the daemon.
      networking.firewall.allowedTCPPorts = [7881];

      services.lk-jwt-service = {
        enable = true;
        inherit keyFile;
        port = jwtPort;
        # Embedded in every JWT as the LiveKit URL clients dial after
        # auth — must point at the path-routed public WS so external
        # browsers can reach it through nginx.
        livekitUrl = sfuWsUrl;
      };
    })
  ];
}
