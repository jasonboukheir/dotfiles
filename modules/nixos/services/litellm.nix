{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.litellm;

  prismaEngines = pkgs.prisma-engines;
  prismaCli = pkgs.prisma;
  py = pkgs.python3;
  ps = pkgs.python3Packages;

  prismaPatched = ps.prisma.overridePythonAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "kkkykin";
      repo = "prisma-client-py";
      rev = "e3d23804414e974558f0035e7faace61bea56cf2";
      hash = "sha256-9/uexdgYsv2S1IRh2SzeV3AO1SEBGPTbKspsEJHPEmw=";
    };
  });

  litellmWithPrisma = (py.withPackages (_: [
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
        ++ [prismaPatched];
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
          "litellm/migrations"
        ];
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
