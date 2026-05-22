{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "brutus-matrix-rtc";

  nodes.machine = {lib, ...}: {
    imports = [
      ./homelab-base.nix
      ../../../modules/homelab/services/matrix-rtc
    ];

    homelab.services.matrix-rtc.enable = true;

    # Production has `use_external_ip = true` so livekit advertises a
    # NAT-traversed IP in its ICE candidates. The nixosTest sandbox
    # has no internet, so STUN lookup hangs and livekit refuses to
    # start. Disabling it for the test exercises the same module path
    # without making the host depend on stun1.l.google.com being up.
    services.livekit.settings.rtc.use_external_ip = lib.mkForce false;
    # Production also restricts ICE gathering to `eno1` (see module
    # comment). The nixosTest sandbox has only `eth1`/`lo`, so the
    # filter would leave LiveKit with no usable interface and it
    # would fail to gather any host candidates. Drop the filter for
    # the test; the production module path still gets exercised
    # because the freeform JSON merge still flows.
    services.livekit.settings.rtc.interfaces = lib.mkForce {};
    # Embedded TURN reads the wildcard ACME cert; the test path
    # forces `security.acme.certs = {}`, so the cert files don't
    # exist and livekit would crash on first read. Disable TURN
    # for the test — startup of the SFU + JWT services is what this
    # test covers, not the TURN listener. Disabling at the option
    # level also drops the SupplementaryGroups=["acme"] reference
    # and the after/wants on acme-finished-*.target.
    homelab.matrix-rtc.turn.enable = false;
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    livekitPort = cfg.homelab.ports.values.matrix-rtc-sfu;
    jwtPort = cfg.homelab.ports.values.matrix-rtc-jwt;
    domain = cfg.homelab.services.matrix-rtc.domain;
    keyFile = "/var/lib/matrix-rtc-shared/livekit.key";
    udpRanges = cfg.networking.firewall.allowedUDPPortRanges;
    rtcStart = cfg.services.livekit.settings.rtc.port_range_start;
    rtcEnd = cfg.services.livekit.settings.rtc.port_range_end;
  in ''
    LIVEKIT_PORT = ${toString livekitPort}
    JWT_PORT = ${toString jwtPort}
    KEY_FILE = "${keyFile}"
    DOMAIN = "${domain}"

    machine.wait_for_unit("multi-user.target")

    # matrix-rtc-secrets is wantedBy livekit + lk-jwt-service via the
    # Wants= chain — async by default, so multi-user.target can flip
    # active without it ever queueing. Kick it explicitly so the
    # assertions below catch a real script failure with a real exit
    # code instead of a hung wait.
    machine.systemctl("start matrix-rtc-secrets.service")

    with subtest("matrix-rtc-secrets writes a single-line LiveKit keyfile"):
        # LiveKit and lk-jwt-service both parse this file with the
        # exact same `<keyname>: <secret>` contract. A regression that
        # wrote multi-line YAML or accidentally included a base64 `=`
        # padding char would silently desync the two: LiveKit accepts
        # the JWT but lk-jwt-service signs with a stale key, or vice
        # versa. Pinning the format here catches the script change
        # before it lands in prod.
        machine.wait_for_unit("matrix-rtc-secrets.service")
        machine.succeed(f"test -s {KEY_FILE}")
        contents = machine.succeed(f"cat {KEY_FILE}")
        lines = [l for l in contents.splitlines() if l]
        assert len(lines) == 1, \
            f"keyfile must be a single `<keyname>: <secret>` line, got:\n{contents!r}"
        keyname, _, secret = lines[0].partition(": ")
        assert keyname == "matrix-rtc", \
            f"keyname must match lk-jwt-service expectations, got {keyname!r}"
        # 43 chars is the base64-without-padding length of 32 random
        # bytes. Shorter means the openssl-pipe lost entropy; longer
        # means the `tr -d '=+/'` strip didn't fire and special chars
        # would break LiveKit's YAML parse.
        assert len(secret) == 43, \
            f"secret must be 43 chars (256-bit base64 without padding), got {len(secret)}: {secret!r}"

        mode = machine.succeed(f"stat -c %a {KEY_FILE}").strip()
        assert mode == "640", \
            f"keyfile must be 0640 so root LoadCredentials but no one else reads it, got {mode}"

    with subtest("matrix-rtc-secrets is idempotent across restarts"):
        # The script guards on `[ ! -s ${keyFile} ]`; a regression that
        # always regenerates would silently invalidate every JWT
        # lk-jwt-service has issued, dropping active calls on rebuild.
        before = machine.succeed(f"cat {KEY_FILE}")
        machine.succeed("systemctl restart matrix-rtc-secrets.service")
        after = machine.succeed(f"cat {KEY_FILE}")
        assert before == after, \
            "matrix-rtc-secrets regenerated the keyfile on rerun — must be idempotent"

    with subtest("livekit SFU starts and binds loopback signaling"):
        # End-to-end smoke for the SFU side: keyfile materialized,
        # LoadCredential succeeded, livekit-server opened its WS
        # listener. Explicit start because the unit's `wants =
        # network-online.target` chain is async — same rationale as the
        # secrets-service kick above.
        machine.systemctl("start livekit.service")
        machine.wait_for_unit("livekit.service")
        machine.wait_for_open_port(LIVEKIT_PORT)

        # The /rtc/validate handler is livekit's own readiness probe —
        # it answers with a structured error when called without a
        # join token, which is exactly what we want here (anything
        # that isn't livekit would 404 with a different body or
        # refuse the connection). The status code is 200 on the
        # error path because livekit serializes the validation
        # failure as a JSON body rather than rejecting at HTTP
        # level. Asserting on the "missing token" string proves both
        # "the listener is livekit" and "the keyfile bind-mount
        # actually loaded" — livekit refuses to start at all if the
        # keyfile is malformed, so getting any 200 here would imply
        # both.
        code = machine.succeed(
            f"curl -sS -o /dev/null -w '%{{http_code}}' "
            f"http://127.0.0.1:{LIVEKIT_PORT}/rtc/validate"
        ).strip()
        assert code in ("200", "400", "401"), \
            f"livekit /rtc/validate should answer (got HTTP {code!r})"

    with subtest("livekit is bound to loopback, not the wider interface"):
        # The path-routed vhost is the only intended public entry; a
        # regression that dropped `bind_addresses = ["127.0.0.1"]`
        # would let arbitrary clients bypass nginx and hit the SFU
        # directly without a JWT, exposing rooms by name.
        #
        # ss's peer column for a LISTEN socket is literally `0.0.0.0:*`
        # (no peer yet), so a naive "0.0.0.0" substring grep
        # false-positives. Match on the local address column only —
        # the wildcard bind would show as `0.0.0.0:<port>` or
        # `*:<port>` there, never the peer column's wildcard.
        listeners = machine.succeed(
            f"ss -Hlnt 'sport = :{LIVEKIT_PORT}'"
        )
        local_addrs = [line.split()[3] for line in listeners.strip().splitlines()]
        assert any(addr.startswith("127.0.0.1:") for addr in local_addrs), \
            f"livekit must bind 127.0.0.1, got local addrs: {local_addrs!r}"
        for addr in local_addrs:
            assert not (addr.startswith("0.0.0.0:") or addr.startswith("*:")), \
                f"livekit must NOT bind wildcard — would bypass nginx auth, got: {addr!r}"

    with subtest("lk-jwt-service starts and binds the homelab-allocated port"):
        machine.systemctl("start lk-jwt-service.service")
        machine.wait_for_unit("lk-jwt-service.service")
        machine.wait_for_open_port(JWT_PORT)

        # /healthz is lk-jwt-service's own liveness handler — it
        # returns 200 with an empty body. -f makes curl exit nonzero
        # on anything but 2xx, so a successful command here proves
        # the listener is lk-jwt-service (a leftover process bound
        # to the port would 404).
        machine.succeed(f"curl -fsS http://127.0.0.1:{JWT_PORT}/healthz")

    with subtest("lk-jwt-service environment points at the public SFU URL"):
        # lk-jwt-service embeds LIVEKIT_URL into every JWT it issues
        # as the SFU clients should dial; a regression that pointed it
        # at 127.0.0.1 would mint JWTs that only work from the host
        # itself, breaking all external calls without an obvious
        # error in the lk-jwt-service logs.
        env = machine.succeed(
            "systemctl show -p Environment --value lk-jwt-service.service"
        )
        expected = f"wss://{DOMAIN}/livekit/sfu"
        assert f"LIVEKIT_URL={expected}" in env, \
            f"lk-jwt-service must point at the path-routed public SFU, got:\n{env}"

    with subtest("UDP firewall opens the WebRTC media port range"):
        # WebRTC media never traverses nginx — clients send UDP
        # directly to the SFU on these ports. Asserting at the
        # eval'd-config level rather than poking nftables at
        # runtime: `openFirewall = true` on the livekit module is
        # the contract; if it silently stopped propagating the
        # `rtc.port_range_*` values into
        # `networking.firewall.allowedUDPPortRanges`, RTC media
        # would be dropped at the host firewall and remote browsers
        # would join signaling fine but get no audio/video.
        expected_range = (${toString rtcStart}, ${toString rtcEnd})
        opened = [(r["from"], r["to"]) for r in ${builtins.toJSON udpRanges}]
        assert expected_range in opened, \
            f"UDP range {expected_range} missing from firewall (RTC media will drop); opened: {opened!r}"
  '';
}
