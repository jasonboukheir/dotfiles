{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.litellm;

# TODO: drop the _6 pin once litellm's schema.prisma stops using the
  # `datasource url` property, which Prisma 7 removed. nixpkgs aliased the
  # default `prisma`/`prisma-engines` to v7 (2025-12-19), so v6 must be
  # requested explicitly. https://github.com/NixOS/nixpkgs/issues/432925
  prismaEngines = pkgs.prisma-engines_6;
  prismaCli = pkgs.prisma_6;
  py = pkgs.python3;
  ps = pkgs.python3Packages;

  # TODO: drop this fork override once upstream prisma-client-py works with
  # the litellm proxy + nixpkgs prisma engines. No upstream issue tracked;
  # investigate before lifting.
  # Fork: https://github.com/kkkykin/prisma-client-py
  prismaPatched = ps.prisma.overridePythonAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "kkkykin";
      repo = "prisma-client-py";
      rev = "e3d23804414e974558f0035e7faace61bea56cf2";
      hash = "sha256-9/uexdgYsv2S1IRh2SzeV3AO1SEBGPTbKspsEJHPEmw=";
    };
  });

  # litellm imports this distribution to locate its bundled prisma migrations
  # (litellm_proxy_extras.utils.ProxyExtrasDBManager). nixpkgs does not package
  # it yet (`# FIXME package litellm-proxy-extras`), so without it prisma
  # `migrate deploy` is silently skipped at startup.
  # https://github.com/jasonboukheir/dotfiles/issues/58
  # The version must match litellm, which pins `litellm-proxy-extras==<version>`
  # in its pyproject.toml; bump both together when bumping ps.litellm.
  litellmProxyExtras = ps.buildPythonPackage rec {
    pname = "litellm-proxy-extras";
    version = "0.4.69";
    pyproject = true;

    src = pkgs.fetchPypi {
      pname = "litellm_proxy_extras";
      inherit version;
      hash = "sha256-jCSgGk3/sTfpXHCaR6toBTWRzN99eKA4xXNI9bKrmQ0=";
    };

    # _get_prisma_dir copies its migrations from the read-only store into
    # LITELLM_MIGRATION_DIR (an ephemeral RuntimeDirectory, empty each boot)
    # with copy2, which stamps the store's read-only mode onto the copies. It is
    # called repeatedly per startup, so a later call cannot overwrite the copies
    # and prisma cannot write baseline migrations into the tree. Make the copied
    # tree writable before returning so repeat calls and baselining both work.
    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build==0.10.7" "uv_build"
      substituteInPlace litellm_proxy_extras/utils.py \
        --replace-fail '            return custom_migrations_dir' '
                  [os.chmod(_p, 0o755 if os.path.isdir(_p) else 0o644) for _r, _d, _fs in os.walk(custom_migrations_dir) for _p in [_r, *(os.path.join(_r, _f) for _f in _fs)]]
                  return custom_migrations_dir'
    '';

    build-system = [ps.uv-build];

    pythonImportsCheck = ["litellm_proxy_extras"];

    meta = {
      description = "Bundled prisma migrations and helpers for the LiteLLM proxy";
      homepage = "https://github.com/BerriAI/litellm";
      license = lib.licenses.mit;
    };
  };

  litellmWithPrisma =
    (py.withPackages (_: [
      prismaPatched
      (ps.litellm.overridePythonAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ [
            prismaCli
            prismaEngines
            pkgs.nodejs
            prismaPatched
          ];

        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace litellm/proxy/schema.prisma \
              --replace-fail '  provider = "prisma-client-py"' \
              $'  provider = "prisma-client-py"\n  output = "../../prisma"'
          '';

        postInstall =
          (old.postInstall or "")
          + ''
            (
              set -eo pipefail
              export HOME="$TMPDIR"
              export PATH="${prismaPatched}/bin:$PATH"
              export PRISMA_EXPECTED_ENGINE_VERSION="$(grep -o '[0-9a-f]\{40\}' "${prismaCli}/lib/prisma/packages/fetch-engine/package.json" | head -1)"
              export PRISMA_QUERY_ENGINE_BINARY="${prismaEngines}/bin/query-engine"
              export PRISMA_QUERY_ENGINE_LIBRARY="${prismaEngines}/lib/libquery_engine.node"
              export PRISMA_SCHEMA_ENGINE_BINARY="${prismaEngines}/bin/schema-engine"
              export PRISMA_FMT_BINARY="${prismaEngines}/bin/prisma-fmt"

              sp="$out/${py.sitePackages}"
              schema="$sp/litellm/proxy/schema.prisma"

              mkdir -p "$sp/prisma"
              chmod -R u+w "$sp" || true
              ${prismaCli}/bin/prisma generate --schema "$schema"
            )
          '';

        dependencies =
          builtins.filter (p: (p.pname or "") != "prisma") (
            (old.dependencies or [])
            ++ (old.optional-dependencies.proxy or [])
            ++ (old.optional-dependencies.extra_proxy or [])
          )
          ++ [prismaPatched litellmProxyExtras];
      }))
    ])).overrideAttrs (old: {
      meta = (old.meta or {}) // {mainProgram = "litellm";};
    });
in {
  config = lib.mkIf cfg.enable {
    services.litellm = {
      package = lib.mkDefault litellmWithPrisma;
      environment = {
        HOME = cfg.stateDir;
        PRISMA_HOME_DIR = cfg.stateDir;
        # Ephemeral, writable, recreated empty each start (see RuntimeDirectory);
        # litellm_proxy_extras reseeds it from the read-only package on boot.
        LITELLM_MIGRATION_DIR = "/run/litellm/migrations";
        PRISMA_QUERY_ENGINE_BINARY = "${prismaEngines}/bin/query-engine";
        PRISMA_QUERY_ENGINE_LIBRARY = "${prismaEngines}/lib/libquery_engine.node";
        PRISMA_SCHEMA_ENGINE_BINARY = "${prismaEngines}/bin/schema-engine";
        PRISMA_FMT_BINARY = "${prismaEngines}/bin/prisma-fmt";
      };
    };

    systemd.services.litellm = {
      path = [prismaCli prismaEngines pkgs.nodejs pkgs.openssl];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        PrivateUsers = lib.mkForce false;
        User = "litellm";
        Group = "litellm";
        StateDirectory = lib.mkForce [
          "litellm"
          "litellm/ui"
          "litellm/tiktoken-cache"
        ];
        # Upstream's litellm module already sets RuntimeDirectory = "litellm";
        # mkForce both so /run/litellm/migrations (LITELLM_MIGRATION_DIR) also
        # exists and is wiped empty each start.
        RuntimeDirectory = lib.mkForce ["litellm" "litellm/migrations"];
        ReadWritePaths = [cfg.stateDir];
      };
    };

    users.groups.litellm = {};
    users.users.litellm = {
      isSystemUser = true;
      group = "litellm";
      home = cfg.stateDir;
      createHome = true;
    };
  };
}
