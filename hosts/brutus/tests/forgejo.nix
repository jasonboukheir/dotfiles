{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "brutus-forgejo";

  nodes.machine = {lib, ...}: {
    imports = [
      ./homelab-base.nix
      ../../../modules/homelab/services/forgejo
    ];

    homelab.services.git.enable = true;

    # The forgejo module derives the OIDC discovery URL from the pocket-id
    # port, but pocket-id itself is out of scope here (id isn't enabled), so
    # pre-allocate the port to satisfy the lookup — mirrors how homelab-base
    # pre-allocates matrix-auth for synapse-only tests.
    homelab.ports.allocate.pocket-id = 1411;
    # forgejo-oauth reconciles the login source against a live Pocket ID,
    # which this offline test doesn't run; its CLI logic is covered against a
    # stub discovery endpoint and on the host. Keep it from auto-starting (and
    # burning the retry budget) so it doesn't muddy the run.
    systemd.services.forgejo-oauth.wantedBy = lib.mkForce [];

    # The bind-mount to the ZFS pool lives in the host's storage.nix; the VM
    # has no pool, so Forgejo uses its default stateDir on the root fs here.

    environment.systemPackages = [pkgs.git];
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    port = cfg.homelab.ports.values.forgejo;
    domain = cfg.homelab.services.git.domain;
    forgejoExe = "${cfg.services.forgejo.package}/bin/forgejo";
  in ''
    PORT = ${toString port}
    DOMAIN = "${domain}"
    BASE = f"http://127.0.0.1:{PORT}"
    # Forgejo CLI must run as the service user with the same work/custom dirs
    # the unit uses, otherwise it can't find app.ini or the DB.
    ADMIN = (
        "runuser -u forgejo -- env "
        "FORGEJO_WORK_DIR=/var/lib/forgejo "
        "FORGEJO_CUSTOM=/var/lib/forgejo/custom ${forgejoExe}"
    )

    machine.wait_for_unit("multi-user.target")

    with subtest("forgejo boots against postgres and serves on its loopback port"):
        # forgejo.service reaching active proves `forgejo migrate` ran the
        # schema against postgres over the peer-auth socket — a broken DB
        # wiring fails the unit here, not at first request.
        machine.wait_for_unit("postgresql.service")
        machine.wait_for_unit("forgejo.service")
        machine.wait_for_open_port(PORT)

        # The forgejo database exists and is owned by the forgejo role
        # (createDatabase + peer auth), not silently falling back to sqlite.
        dbs = machine.succeed("runuser -u postgres -- psql -lqt")
        assert "forgejo" in dbs, f"forgejo database must exist:\n{dbs}"

        # /api/v1/version is Forgejo's unauthenticated liveness probe.
        version = machine.succeed(f"curl -fsS {BASE}/api/v1/version")
        assert '"version"' in version, f"version endpoint should answer: {version!r}"

    with subtest("public registration is closed (accounts come from OIDC/admin only)"):
        # DISABLE_REGISTRATION + ALLOW_ONLY_EXTERNAL_REGISTRATION: the
        # unauthenticated user-creation API must be rejected so accounts only
        # ever come from Pocket ID (wired in Phase 2) or the admin CLI.
        rc, code = machine.execute(
            "curl -sS -o /dev/null -w '%{http_code}' -X POST "
            "-H 'Content-Type: application/json' "
            '-d \'{"username":"intruder","email":"x@test.local","password":"hunter2hunter2"}\' '
            f"{BASE}/api/v1/admin/users"
        )
        assert code.strip() in ("401", "403"), \
            f"unauthenticated user creation must be rejected, got {code!r}"

    with subtest("git clone + push over HTTP works against a fresh repo"):
        # The end-to-end forge contract: an account can be provisioned, hold
        # a scoped token, and round-trip a repo over the smart-HTTP
        # transport (clone, commit, push) — the path agents and humans use.
        machine.succeed(
            f"{ADMIN} admin user create --admin --username tester "
            "--email tester@test.local --password hunter2hunter2 "
            "--must-change-password=false"
        )
        token = machine.succeed(
            f"{ADMIN} admin user generate-access-token --username tester "
            "--scopes write:repository,write:user --raw"
        ).strip()

        machine.succeed(
            "curl -fsS -X POST -H 'Content-Type: application/json' "
            f"-H 'Authorization: token {token}' "
            '-d \'{"name":"test","auto_init":true}\' '
            f"{BASE}/api/v1/user/repos"
        )

        repo = f"http://tester:{token}@127.0.0.1:{PORT}/tester/test.git"
        machine.succeed(f"git clone {repo} /tmp/test")
        machine.succeed(
            "git -C /tmp/test config user.email tester@test.local",
            "git -C /tmp/test config user.name tester",
            "git -C /tmp/test checkout -b feature/smoke",
            "echo hello > /tmp/test/hello.txt",
            "git -C /tmp/test add hello.txt",
            "git -C /tmp/test commit -m 'smoke'",
            "git -C /tmp/test push origin feature/smoke",
        )

        # The pushed branch is visible through the API, proving the push
        # reached the server side and was recorded, not just accepted locally.
        branches = machine.succeed(
            f"curl -fsS -H 'Authorization: token {token}' "
            f"{BASE}/api/v1/repos/tester/test/branches"
        )
        assert "feature/smoke" in branches, f"pushed branch must exist server-side:\n{branches}"
  '';
}
