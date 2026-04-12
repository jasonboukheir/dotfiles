final: prev: let
  version = "0.1.10";

  sources = {
    x86_64-darwin = {
      url = "https://github.com/nicosuave/gmx/releases/download/v${version}/gmx-${version}-macos-x86_64.tar.gz";
      hash = "sha256-v2lAEwEiTQZYhY3pDiT3fbZI2IduuhQ43TC8GPFC6qQ=";
    };
    aarch64-darwin = {
      url = "https://github.com/nicosuave/gmx/releases/download/v${version}/gmx-${version}-macos-arm64.tar.gz";
      hash = "sha256-zkxWcw0cE/W1JKzaZBwe2purkf3Hwz5GjqbQTRqUXek=";
    };
  };

  src = final.fetchurl sources.${final.stdenv.hostPlatform.system};
in {
  gmx = final.stdenvNoCC.mkDerivation {
    pname = "gmx";
    inherit version src;

    sourceRoot = ".";

    nativeBuildInputs = [final.fixDarwinDylibNames final.installShellFiles];

    installPhase = ''
      install -Dm755 gmx $out/bin/gmx
      installShellCompletion --cmd gmx \
        --bash <($out/bin/gmx completions bash) \
        --fish <($out/bin/gmx completions fish) \
        --zsh <($out/bin/gmx completions zsh)
    '';

    meta = {
      description = "Terminal multiplexer for Ghostty on macOS with session persistence via zmx";
      homepage = "https://github.com/nicosuave/gmx";
      platforms = builtins.attrNames sources;
      mainProgram = "gmx";
    };
  };
}
