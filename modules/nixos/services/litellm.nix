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

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail "uv_build==0.10.7" "uv_build"
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
        LITELLM_MIGRATION_DIR = "${cfg.stateDir}/migrations";
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
        ReadWritePaths = [cfg.stateDir];
        # litellm_proxy_extras copies its bundled prisma migrations into
        # LITELLM_MIGRATION_DIR at startup, then chdirs there to run
        # `prisma migrate deploy`. The package files live read-only in the Nix
        # store, so seed the dir from them as writable each start — otherwise
        # the copy fails overwriting stale read-only files (PermissionError)
        # and prisma cannot write baseline migrations into a read-only tree.
        ExecStartPre = let
          migrations = "${litellmProxyExtras}/${py.sitePackages}/litellm_proxy_extras";
        in pkgs.writeShellScript "litellm-seed-migrations" ''
          set -eu
          ${pkgs.coreutils}/bin/rm -rf ${cfg.stateDir}/migrations
          ${pkgs.coreutils}/bin/cp -rT ${migrations} ${cfg.stateDir}/migrations
          ${pkgs.coreutils}/bin/chmod -R u+w ${cfg.stateDir}/migrations
        '';
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
