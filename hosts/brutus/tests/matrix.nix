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

    homelab.services.synapse.enable = true;

    # The matrix-auth module owns these in production; tests don't run
    # MAS, so stand in for the secrets oneshot's output. Distinctive
    # payloads catch a regression that silently aliased synapse's
    # LoadCredential to the wrong file.
    systemd.tmpfiles.rules = [
      "d /var/lib/matrix-mas-shared 0750 root root - -"
      "f /var/lib/matrix-mas-shared/synapse_client_secret 0600 root root - test-stub-mas-synapse-client-secret"
      "f /var/lib/matrix-mas-shared/admin_token 0600 root root - test-stub-mas-admin-token"
    ];

    # matrix-synapse's unit `Requires=` matrix-authentication-service-secrets,
    # which would otherwise fail-the-job since MAS isn't in scope here.
    # Stub it as a no-op so the dependency resolves and synapse can start.
    systemd.services.matrix-authentication-service-secrets = {
      description = "stub for matrix-synapse test (MAS not in scope)";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
      };
    };
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

    with subtest("matrix-synapse LoadCredentials the two MAS-shared values"):
        # The MSC3861 cutover replaced the single pocket-id oidc secret
        # with two values shared from the matrix-auth module:
        # synapse's client_secret inside MAS, and the admin token MAS
        # hands to synapse for /_synapse/admin. Both must LoadCredential
        # from /var/lib/matrix-mas-shared/ — never from the raw pocket-id
        # secrets path the legacy oidc_providers config used.
        unit = machine.succeed("systemctl cat matrix-synapse.service")
        assert "LoadCredential=mas_synapse_client_secret:/var/lib/matrix-mas-shared/synapse_client_secret" in unit, \
            f"matrix-synapse unit must LoadCredential mas_synapse_client_secret:\n{unit}"
        assert "LoadCredential=mas_admin_token:/var/lib/matrix-mas-shared/admin_token" in unit, \
            f"matrix-synapse unit must LoadCredential mas_admin_token:\n{unit}"
        for stale in ("oidc_client_secret", "smtp_password", "/run/pocket-id-secrets/matrix-synapse"):
            assert stale not in unit, \
                f"stale credential reference '{stale}' lingering in unit:\n{unit}"

    with subtest("rendered homeserver.yaml delegates auth via MSC3861 (not legacy oidc_providers)"):
        # Element X requires MAS-delegated auth — the legacy `oidc_providers`
        # block only advertises `m.login.sso` which Element X rejects. The
        # cutover must produce an `experimental_features.msc3861` block
        # pointing at MAS and the bind-mount paths LoadCredential lands.
        yaml = machine.succeed(f"cat {SYNAPSE_CONFIG}")
        assert "oidc_providers" not in yaml, \
            f"legacy oidc_providers must be gone — MSC3861 fully replaces it:\n{yaml}"
        for needle in (
            "experimental_features:",
            "msc3861:",
            "client_id: 0000000000000000000SYNAPSE",
            "client_secret_path: /run/credentials/matrix-synapse.service/mas_synapse_client_secret",
            "admin_token_path: /run/credentials/matrix-synapse.service/mas_admin_token",
        ):
            assert needle in yaml, \
                f"{needle!r} missing from synapse config (MSC3861 delegation broken):\n{yaml}"

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

    with subtest("MAS-shared secrets round-trip into synapse's credentials dir"):
        # The LoadCredential bind-mount is private to matrix-synapse.service,
        # but root on the host can read it via /proc/<pid>/root which
        # preserves the unit's mount namespace. This proves synapse can
        # actually read the secrets at the paths the MSC3861 config
        # points to, not just that the unit setting names the right keys.
        #
        # The stubbed payloads are distinctive on purpose so the assertion
        # fails loudly if the bind-mount silently aliased to the wrong
        # file (e.g., a regression that swapped the two credentials).
        pid = machine.succeed(
            "systemctl show -p MainPID --value matrix-synapse.service"
        ).strip()
        client_secret = machine.succeed(
            f"cat /proc/{pid}/root/run/credentials/matrix-synapse.service/mas_synapse_client_secret"
        ).strip()
        assert client_secret == "test-stub-mas-synapse-client-secret", \
            f"mas_synapse_client_secret credential did not round-trip: {client_secret!r}"
        admin_token = machine.succeed(
            f"cat /proc/{pid}/root/run/credentials/matrix-synapse.service/mas_admin_token"
        ).strip()
        assert admin_token == "test-stub-mas-admin-token", \
            f"mas_admin_token credential did not round-trip: {admin_token!r}"
  '';
}
