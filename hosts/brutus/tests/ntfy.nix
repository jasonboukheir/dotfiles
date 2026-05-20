{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "brutus-ntfy";

  nodes.machine = {...}: {
    imports = [
      ./homelab-base.nix
      ../../../modules/homelab/services/ntfy.nix
    ];

    homelab.services.ntfy.enable = true;
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    ntfyPort = cfg.homelab.ports.values.ntfy;
    serverYml = "/etc/ntfy/server.yml";
    domain = cfg.homelab.services.ntfy.domain;
  in ''
    NTFY_PORT = ${toString ntfyPort}
    SERVER_YML = "${serverYml}"
    DOMAIN = "${domain}"

    machine.wait_for_unit("multi-user.target")

    with subtest("ntfy-sh starts and binds its loopback listener"):
        # End-to-end smoke: unit reached active, http listener is up on the
        # homelab-allocated port. Loopback-only on purpose — the framework
        # vhost (covered separately) is what exposes ntfy to the internet.
        machine.wait_for_unit("ntfy-sh.service")
        machine.wait_for_open_port(NTFY_PORT)

        # /v1/health is ntfy's canonical liveness probe; returns
        # {"healthy":true}. Hitting it confirms the listener is serving
        # ntfy itself, not a leftover process that grabbed the port.
        response = machine.succeed(
            f"curl -fsS http://127.0.0.1:{NTFY_PORT}/v1/health"
        )
        assert '"healthy":true' in response, \
            f"/v1/health should report healthy, got: {response!r}"

    with subtest("rendered server.yml uses homelab port + external base-url"):
        # base-url is load-bearing: UnifiedPush/Matrix push-gateway clients
        # use the URL the server advertises, not the one they connected
        # through. A regression that defaulted it to localhost would
        # silently break push delivery from outside the LAN.
        yaml = machine.succeed(f"cat {SERVER_YML}")
        assert f"base-url: https://{DOMAIN}" in yaml, \
            f"base-url must point at the external homelab domain:\n{yaml}"
        assert f"listen-http: 127.0.0.1:{NTFY_PORT}" in yaml, \
            f"listen-http must bind the homelab-allocated port on loopback:\n{yaml}"
        assert "behind-proxy: true" in yaml, \
            f"behind-proxy must be set so ntfy trusts X-Forwarded-For from nginx:\n{yaml}"

    with subtest("publish + subscribe round-trips a message"):
        # Proves the auth-file / cache-file state dirs are writable under
        # DynamicUser+StateDirectory and that the JSON subscribe stream
        # actually delivers — the bit users care about. Subscribe in the
        # background with a short poll deadline, publish, then drain.
        machine.succeed(
            f"curl -fsS -X POST -d 'hello-from-test' "
            f"http://127.0.0.1:{NTFY_PORT}/test-topic"
        )
        delivered = machine.succeed(
            f"curl -fsS 'http://127.0.0.1:{NTFY_PORT}/test-topic/json?poll=1'"
        )
        assert "hello-from-test" in delivered, \
            f"published message did not round-trip through /poll: {delivered!r}"
  '';
}
