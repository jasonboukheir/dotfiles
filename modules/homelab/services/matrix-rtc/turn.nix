{
  config,
  lib,
  ...
}: let
  cfg = config.homelab.matrix-rtc.turn;
  homelabCfg = config.homelab.services.matrix-rtc;
  domain = homelabCfg.domain;

  # Wildcard ACME cert covering `${domain}` as a SAN (added via
  # `extraDomainNames` in the homelab services framework).
  acmeCertDir = "/var/lib/acme/${config.homelab.domain}";

  # Relay allocations are loopback-only since TURN and the SFU live on
  # the same host — no port forwarding needed for this range, so it's
  # hardcoded rather than exposed as an option.
  relayRangeStart = 49160;
  relayRangeEnd = 49260;
in {
  options.homelab.matrix-rtc.turn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = homelabCfg.enable;
      defaultText = lib.literalExpression "config.homelab.services.matrix-rtc.enable";
      description = ''
        Enable the LiveKit embedded TURN server. Element Call clients
        relay through this when they can't reach the SFU directly
        (symmetric NAT, UDP-blocking corporate/hotel wifi, CGNAT).

        Reads the wildcard ACME cert at
        `/var/lib/acme/''${config.homelab.domain}/`; LiveKit's
        DynamicUser is granted membership of the `acme` group so the
        TURN listener can load the cert without weakening its 0750
        directory mode.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3478;
      description = ''
        UDP port the TURN server listens on. 3478 is the IANA-registered
        STUN/TURN port and is what most WebRTC clients try first. The
        router must DNAT this UDP port to the host for off-LAN clients
        to reach it.
      '';
    };

    tcpPort = lib.mkOption {
      type = lib.types.port;
      default = 5349;
      description = ''
        TCP port the TURN server listens on for TURN-over-TLS (TURNS).
        5349 is the IANA-registered TURNS port. This is the fallback
        clients use on networks that block UDP entirely — the router
        must DNAT this TCP port to the host.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the TURN UDP and TLS ports on the host firewall. Disable
        when the host sits behind an external firewall that handles
        ingress filtering itself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.livekit.settings.turn = {
      enabled = true;
      inherit domain;
      cert_file = "${acmeCertDir}/fullchain.pem";
      key_file = "${acmeCertDir}/key.pem";
      udp_port = cfg.port;
      tls_port = cfg.tcpPort;
      relay_range_start = relayRangeStart;
      relay_range_end = relayRangeEnd;
    };

    # LiveKit runs under DynamicUser, so its on-the-fly UID can't read
    # the acme-group-owned cert files by default. SupplementaryGroups
    # adds the dynamic user to `acme` at process start. Ordering
    # against `acme-finished-*` ensures the cert exists before TURN
    # tries to load it on first boot.
    systemd.services.livekit = {
      serviceConfig.SupplementaryGroups = ["acme"];
      after = ["acme-finished-${config.homelab.domain}.target"];
      wants = ["acme-finished-${config.homelab.domain}.target"];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [cfg.port];
      allowedTCPPorts = [cfg.tcpPort];
    };
  };
}
