{
  pkgs,
  inputs,
}:
pkgs.testers.nixosTest {
  name = "brutus-matrix";

  nodes.machine = {lib, ...}: {
    imports = [
      ./homelab-base.nix
      ../../../modules/homelab/services/matrix-synapse
    ];

    # Give synapse enough headroom — first-boot schema bootstrap on a stock
    # VM regularly OOMs at the default 1024 MiB.
    virtualisation.memorySize = 2048;

    homelab.services.chat.enable = true;

    # Stand-in for the file that pocket-id-provisioner would normally drop
    # at /run/pocket-id-secrets/<client_id>. The headline fix changed
    # matrix-synapse's `client_secret_path` from this raw path (synapse
    # can't read it under PrivateTmp/ProtectSystem) to the LoadCredential
    # bind-mount target. Stub the source file so the LoadCredential copy
    # actually happens and we can confirm the bind-mount path is populated.
    #
    # Distinctive payload makes the round-trip assertion below precise.
    systemd.tmpfiles.rules = [
      "f /run/pocket-id-secrets/matrix-synapse 0600 root root - test-stub-oidc-secret-payload"
    ];
  };

  testScript = {nodes, ...}: let
    cfg = nodes.machine;
    synapsePort = cfg.homelab.ports.values.matrix-synapse;
    synapseConfig = cfg.services.matrix-synapse.configFile;
    secretsFile = "${cfg.services.matrix-synapse.dataDir}/secrets.yaml";
  in ''
    import re

    SYNAPSE_PORT = ${toString synapsePort}
    SYNAPSE_CONFIG = "${synapseConfig}"
    SECRETS_FILE = "${secretsFile}"

    machine.wait_for_unit("multi-user.target")

    # synapse + secrets are Wants/After multi-user.target's tail; they
    # haven't necessarily been queued by the time multi-user activates.
    # Kick the secrets oneshot explicitly so the test doesn't race the
    # default boot order — this also surfaces failures with a real exit
    # code instead of a hung wait.
    machine.systemctl("start matrix-synapse-secrets.service")

    with subtest("matrix-synapse-secrets oneshot writes macaroon + form secrets"):
        # matrix-synapse.service Requires= the oneshot, so reaching active
        # multi-user has already ordered it. Asserting on the unit's Result
        # rather than just file presence catches the case where the script
        # exits 0 without writing (e.g., if the heredoc-style redirection
        # silently fails under UMask 0077).
        machine.wait_for_unit("matrix-synapse-secrets.service")
        machine.succeed(f"test -s {SECRETS_FILE}")
        contents = machine.succeed(f"cat {SECRETS_FILE}")
        for key in ("macaroon_secret_key:", "form_secret:"):
            assert key in contents, f"{key} missing from {SECRETS_FILE}:\n{contents}"

        # UMask=0077 in the unit must produce 0600 — anything looser leaks
        # synapse's session-signing key to other local users. owner check
        # catches the symmetric regression where the unit runs as root and
        # synapse can't read the file at startup.
        mode = machine.succeed(f"stat -c %a {SECRETS_FILE}").strip()
        assert mode == "600", f"expected 0600 perms on secrets file, got {mode}"
        owner = machine.succeed(f"stat -c %U:%G {SECRETS_FILE}").strip()
        assert owner == "matrix-synapse:matrix-synapse", \
            f"secrets file owner must be matrix-synapse:matrix-synapse, got {owner}"

    with subtest("matrix-synapse-secrets is idempotent across restarts"):
        # The oneshot guards with `[ ! -s "$file" ]`. A regression that
        # always regenerates would silently invalidate every existing
        # session token on rebuild — exactly the kind of bug that's
        # invisible until users complain about being logged out.
        before = machine.succeed(f"cat {SECRETS_FILE}")
        machine.succeed("systemctl restart matrix-synapse-secrets.service")
        after = machine.succeed(f"cat {SECRETS_FILE}")
        assert before == after, \
            "matrix-synapse-secrets regenerated secrets on rerun — must be idempotent"

    with subtest("matrix-synapse LoadCredential names the oidc secret, not smtp"):
        # The pre-fix LoadCredential carried `smtp_password:<path>` left
        # over from an email block synapse no longer uses. The post-fix
        # version must load `oidc_client_secret` from pocket-id-provisioner's
        # output dir. Assert both halves to pin both directions of drift.
        unit = machine.succeed("systemctl cat matrix-synapse.service")
        assert "LoadCredential=oidc_client_secret:/run/pocket-id-secrets/matrix-synapse" in unit, \
            f"matrix-synapse unit must LoadCredential oidc_client_secret:\n{unit}"
        assert "smtp_password" not in unit, \
            f"stale smtp_password LoadCredential lingering in unit:\n{unit}"

    with subtest("rendered homeserver.yaml points client_secret_path at the bind-mount"):
        # The headline of `fix oidc load credential`: synapse reads the
        # client secret from the credentials bind-mount, NOT from the raw
        # /run/pocket-id-secrets path (which synapse's sandbox can't reach).
        # If this regresses, oidc login fails at startup with an opaque
        # "could not load client secret" — easier to catch here than in
        # prod.
        yaml = machine.succeed(f"cat {SYNAPSE_CONFIG}")
        assert (
            "client_secret_path: "
            "/run/credentials/matrix-synapse.service/oidc_client_secret"
        ) in yaml, f"client_secret_path drift:\n{yaml}"

    with subtest("allow_unsafe_locale sits on database, not database.args"):
        # `fixup matrix` moved this key out of database.args (where synapse
        # would forward it to psycopg2 as an unknown connect kwarg and
        # raise) into the outer database block (where synapse honors it
        # to skip the en_US.UTF-8 collation check). The structural fix is
        # invisible to a `grep allow_unsafe_locale` so we match on the
        # YAML indentation: 2 spaces = database.allow_unsafe_locale, 4
        # spaces would be database.args.allow_unsafe_locale.
        yaml = machine.succeed(f"cat {SYNAPSE_CONFIG}")
        assert re.search(r"^  allow_unsafe_locale:\s*true\b", yaml, re.M), \
            f"allow_unsafe_locale must live directly under `database:` (2-space indent):\n{yaml}"
        assert not re.search(r"^    allow_unsafe_locale:", yaml, re.M), \
            f"allow_unsafe_locale must not be nested under database.args:\n{yaml}"

    with subtest("matrix-synapse starts and binds its listener"):
        # The end-to-end smoke: secrets oneshot ran, LoadCredential
        # succeeded, postgres schema bootstrap completed, synapse opened
        # its HTTP listener. Generous timeout because first-boot schema
        # migrations on a cold VM take a while.
        #
        # Same rationale as the explicit secrets-service start above:
        # synapse is wantedBy=multi-user.target via the upstream module,
        # but Wants= is async — multi-user.target can activate without it,
        # leaving the unit "inactive" with no pending jobs by the time
        # the test polls. Kick it explicitly so a real failure raises
        # here instead of looking like a no-op.
        machine.systemctl("start matrix-synapse.service")
        machine.wait_for_unit("matrix-synapse.service", timeout=300)
        machine.wait_for_open_port(SYNAPSE_PORT, timeout=300)

        # /_matrix/client/versions is the canonical "synapse is alive"
        # probe — unauthenticated, always present, returns JSON. Hitting
        # it confirms the listener is actually serving synapse (not, say,
        # a leftover process that bound the port).
        response = machine.succeed(
            f"curl -fsS http://127.0.0.1:{SYNAPSE_PORT}/_matrix/client/versions"
        )
        assert '"versions"' in response, \
            f"/_matrix/client/versions should return a versions list, got: {response!r}"

    with subtest("oidc_client_secret round-trips into synapse's credentials dir"):
        # The LoadCredential bind-mount is private to matrix-synapse.service,
        # but root on the host can read it via /proc/<pid>/root which
        # preserves the unit's mount namespace. This proves synapse can
        # actually read the secret at the path its config points to, not
        # just that the unit setting names the right key.
        #
        # The stubbed payload is distinctive on purpose so the assertion
        # fails loudly if the bind-mount silently aliased to the wrong
        # file (e.g., a regression that swapped back to smtp_password).
        pid = machine.succeed(
            "systemctl show -p MainPID --value matrix-synapse.service"
        ).strip()
        payload = machine.succeed(
            f"cat /proc/{pid}/root/run/credentials/matrix-synapse.service/oidc_client_secret"
        ).strip()
        assert payload == "test-stub-oidc-secret-payload", \
            f"oidc credential did not round-trip into the unit's bind-mount: {payload!r}"
  '';
}
