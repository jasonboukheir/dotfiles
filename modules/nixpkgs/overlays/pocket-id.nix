final: prev: {
  pocket-id = prev.pocket-id.overrideAttrs (finalAttrs: previousAttrs: {
    version = "2.2.0";

    src = prev.fetchFromGitHub {
      owner = "pocket-id";
      repo = "pocket-id";
      tag = "v${finalAttrs.version}";
      hash = "sha256-n1jNU7+eNO7MFUWB7+EnssACMvNoMcJqPk0AvyIr9h8=";
    };

    vendorHash = "sha256-hMhOG/2xnI/adjg8CnA0tRBD8/OFDsTloFXC8iwxlV0=";

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

        hash = "sha256-jhlHrekVk0sNLwo8LFQY6bgX9Ic0xbczM6UTzmZTnPI=";
      };
    });
  });
}
