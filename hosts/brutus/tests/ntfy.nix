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
        assert "web-root: disable" in yaml, \
            f"web-root must be disabled so the SPA is not served publicly:\n{yaml}"

    with subtest("web UI is not served, but the API still answers"):
        # The SPA at / and the /static assets are the only operator-
        # facing surface; with web-root: disable they must 404 (no app
        # shell, no bundled JS), while pure-API paths keep responding.
        # /v1/health is the canonical liveness probe and proves the
        # daemon is still up; the Matrix Push Gateway is covered in its
        # own subtest below. Together these pin "UI gone, API intact"
        # so a future flip back to web-root: app fails loudly here.
        for path in ("/", "/app", "/static/css/app.css"):
            rc, code = machine.execute(
                "curl -sS -o /dev/null -w '%{http_code}' "
                f"http://127.0.0.1:{NTFY_PORT}{path}"
            )
            assert code.strip() == "404", \
                f"{path} must 404 with web-root disabled, got HTTP {code!r}"
        machine.succeed(f"curl -fsS http://127.0.0.1:{NTFY_PORT}/v1/health")

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

    with subtest("operator ACL grants make up* topics usable for family accounts"):
        # The post-deploy runbook is: anonymous write on up* (so
        # Synapse can publish without ntfy creds) + a real user per
        # phone with read access. Exercising both rules together
        # against the running daemon catches regressions in the
        # SQLite-backed access control system that the rendered yaml
        # asserts above can't see.
        machine.succeed("ntfy access '*' 'up*' write-only")
        machine.succeed(
            "NTFY_PASSWORD=testpass ntfy user add tester"
        )
        machine.succeed("ntfy access tester 'up*' read-write")

        # Authenticated subscribe must succeed; anonymous subscribe to
        # the same topic must NOT. ntfy emits an `{"event":"open",...}`
        # line as soon as the auth check passes and the stream
        # registers, so a single curl --max-time call is enough to
        # distinguish "auth + ACL worked" from "401" without managing
        # a long-running background process. curl exits 28 (timeout)
        # by design after --max-time, so we use machine.execute and
        # assert on stdout content rather than exit code.
        _, ok = machine.execute(
            "curl -sS --no-buffer --user tester:testpass --max-time 3 "
            f"'http://127.0.0.1:{NTFY_PORT}/upTESTTOPIC/json'"
        )
        assert '"event":"open"' in ok, \
            f"tester should be able to subscribe to up*, got: {ok!r}"
        _, code = machine.execute(
            "curl -sS -o /dev/null -w '%{http_code}' "
            f"http://127.0.0.1:{NTFY_PORT}/upTESTTOPIC/json?poll=1"
        )
        assert code.strip() in ("401", "403"), \
            f"anonymous subscribe to up* must stay denied, got HTTP {code!r}"

    with subtest("matrix push gateway is wired and speaks the Sygnal protocol"):
        # The whole point of ntfy in this homelab: act as the Matrix
        # Push Gateway for the UnifiedPush flow on family Android
        # devices. The gateway endpoint /_matrix/push/v1/notify is
        # always-on (no enable flag) and reuses the up* write ACL the
        # operator-run rule above grants. Two valid outcomes prove the
        # route is wired:
        #   - HTTP 200, body {"rejected":[]} — the steady state once a
        #     phone's UnifiedPush distributor is registered as a
        #     "RateVisitor" on the topic.
        #   - HTTP 507 with code 50701 "cannot publish to UnifiedPush
        #     topic without previously active subscriber" — the deploy
        #     state, while visitor-subscriber-rate-limiting is on and
        #     no Android distributor has subscribed yet. Synapse
        #     retries on 5xx, which is exactly the behavior we want
        #     (no pusher deletion).
        # Distinguishing the two against the test VM would require
        # bootstrapping a RateVisitor end-to-end (auth flow + open
        # stream with very specific timing); both responses prove the
        # route exists, the pushkey is validated, and the up* ACL
        # accepted the publish. The 4xx/5xx-not-507 path is the only
        # real regression — that means the route disappeared or the
        # ACL stopped accepting Synapse's anonymous POST.
        push_url = f"http://127.0.0.1:{NTFY_PORT}/_matrix/push/v1/notify"
        pushkey  = f"https://{DOMAIN}/upTESTTOPIC?up=1"
        payload  = (
            '{"notification":{'
            '"event_id":"$test:matrix.test.local",'
            '"room_id":"!room:matrix.test.local",'
            '"type":"m.room.message",'
            '"sender":"@sender:matrix.test.local",'
            '"counts":{"unread":1},'
            '"devices":[{'
            '"app_id":"org.unifiedpush.distributor.ntfy",'
            f'"pushkey":"{pushkey}",'
            '"pushkey_ts":0,'
            '"data":{}'
            "}]}}"
        )
        response = machine.succeed(
            "curl -sS -X POST -H 'Content-Type: application/json' "
            f"-w '\\nHTTP:%{{http_code}}' -d '{payload}' {push_url}"
        )
        compact = response.replace(" ", "")
        wired = (
            ('"rejected":[]' in compact and "HTTP:200" in compact)
            or ('"code":50701' in compact and "HTTP:507" in compact)
        )
        assert wired, \
            f"gateway response must be either 200+rejected:[] or 507+code 50701, got: {response!r}"

    with subtest("matrix push gateway rejects pushkeys for the wrong host"):
        # If a Matrix client somewhere registers a pushkey pointing at
        # *someone else's* ntfy server and that homeserver still POSTs
        # to ours (misconfiguration or hostile), the gateway must mark
        # the pushkey rejected so Synapse stops sending. ntfy enforces
        # this via strings.HasPrefix(pushkey, base-url + "/").
        push_url = f"http://127.0.0.1:{NTFY_PORT}/_matrix/push/v1/notify"
        foreign_pushkey = "https://ntfy.example.com/upFOREIGN?up=1"
        payload = (
            '{"notification":{'
            '"event_id":"$test:matrix.test.local",'
            '"room_id":"!room:matrix.test.local",'
            '"type":"m.room.message",'
            '"sender":"@sender:matrix.test.local",'
            '"counts":{"unread":1},'
            '"devices":[{'
            '"app_id":"org.unifiedpush.distributor.ntfy",'
            f'"pushkey":"{foreign_pushkey}",'
            '"pushkey_ts":0,'
            '"data":{}'
            "}]}}"
        )
        response = machine.succeed(
            "curl -fsS -X POST -H 'Content-Type: application/json' "
            f"-d '{payload}' {push_url}"
        )
        compact = response.replace(" ", "")
        assert f'"rejected":["{foreign_pushkey}"]' in compact, \
            f"foreign-host pushkey must come back in rejected list, got: {response!r}"
  '';
}
