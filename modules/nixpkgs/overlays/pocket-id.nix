final: prev: {
  pocket-id = (prev.pocket-id.override {
    buildGo125Module = prev.buildGo126Module;
  }).overrideAttrs (finalAttrs: previousAttrs: {
    version = "2.7.0";

    src = prev.fetchFromGitHub {
      owner = "pocket-id";
      repo = "pocket-id";
      tag = "v${finalAttrs.version}";
      hash = "sha256-rWU1jldmdtXDcHrFty/Pmll1xFUQnLFF12j833M05rQ=";
    };

    # CVE-2026-28513 and CVE-2026-43983 fixed upstream in v2.6.0+
    patches = [];

    vendorHash = "sha256-nr9L7FVUQYzn+bLtvqKGsYydVCjW/fl53Od9lzRv8gk=";

    checkFlags =
      (previousAttrs.checkFlags or [])
      ++ [
        # Skip the test that tries to hit example.com
        "-skip=TestOidcService_downloadAndSaveLogoFromURL"
      ];

    frontend = previousAttrs.frontend.overrideAttrs (frontendFinal: frontendPrev: {
      pnpmDeps = prev.fetchPnpmDeps {
        inherit (finalAttrs) pname version src;

        pnpm = prev.pnpm_10;
        fetcherVersion = 3; # Keep consistent with original

        hash = "sha256-DVNzFFHMMasKEx+adAhisE32qtirBhJlfMHKrOVl1dM=";
      };
    });
  });
}
