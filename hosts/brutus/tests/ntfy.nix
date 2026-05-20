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

    with subtest("rendered server.yml is locked down by default"):
        # The server is exposed to the public internet on port 8443 and
        # ntfy has no LDAP/OIDC integration upstream — a regression that
        # flipped auth-default-access back to read-write would silently
        # turn brutus into an open relay until someone noticed traffic.
        # visitor-subscriber-rate-limiting is the matched safety net for
        # UnifiedPush's anonymous-write pattern.
        yaml = machine.succeed(f"cat {SERVER_YML}")
        assert "auth-default-access: deny-all" in yaml, \
            f"auth-default-access must default-deny:\n{yaml}"
        assert "visitor-subscriber-rate-limiting: true" in yaml, \
            f"visitor-subscriber-rate-limiting must be on to charge subscribers:\n{yaml}"

    with subtest("anonymous publish is denied under deny-all"):
        # The actual safety contract: with no ACL rows yet, an
        # unauthenticated POST to a random topic must be rejected. This
        # is what stops a freshly deployed server from being a public
        # write-only mailbox before the operator runs `ntfy user add`.
        # 401 (Unauthorized) is the documented response; we check for
        # the family rather than the exact code so a future bump that
        # switches to 403 doesn't silently break the test.
        rc, body = machine.execute(
            f"curl -sS -o /dev/null -w '%{{http_code}}' "
            f"-X POST -d 'should-not-deliver' "
            f"http://127.0.0.1:{NTFY_PORT}/anon-publish-probe"
        )
        assert body.strip() in ("401", "403"), \
            f"anonymous POST under deny-all must 401/403, got {body!r}"
  '';
}
