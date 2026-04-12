final: prev: let
  version = "0.4.2";

  sources = {
    x86_64-linux = {
      url = "https://zmx.sh/a/zmx-${version}-linux-x86_64.tar.gz";
      hash = "sha256-JSPSkAbo4NdoyA9APK0pROkNWMuj9oqRJ3sLgNDB8jc=";
    };
    aarch64-linux = {
      url = "https://zmx.sh/a/zmx-${version}-linux-aarch64.tar.gz";
      hash = "sha256-Lj/CpiV0CGJmNEgOWmhMwk5ys0+BPQiwCKNZ+VDvyjs=";
    };
    x86_64-darwin = {
      url = "https://zmx.sh/a/zmx-${version}-macos-x86_64.tar.gz";
      hash = "sha256-GunNG+i69eUaaci6kVZpip+DPgiRFmQoEbhaRE4mJ8c=";
    };
    aarch64-darwin = {
      url = "https://zmx.sh/a/zmx-${version}-macos-aarch64.tar.gz";
      hash = "sha256-V9SYOm6n7VwEt4ebkNQ0zCAtwLY3ysgK59WuCbQesWA=";
    };
  };

  src = final.fetchurl sources.${final.stdenv.hostPlatform.system};
in {
  zmx = final.stdenvNoCC.mkDerivation {
    pname = "zmx";
    inherit version src;

    sourceRoot = ".";

    nativeBuildInputs =
      [final.installShellFiles]
      ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [final.fixDarwinDylibNames];

    installPhase = ''
      install -Dm755 zmx $out/bin/zmx
      installShellCompletion --cmd zmx \
        --bash <($out/bin/zmx completions bash) \
        --fish <($out/bin/zmx completions fish) \
        --zsh <($out/bin/zmx completions zsh)
    '';

    meta = {
      description = "Session persistence for terminal processes";
      homepage = "https://github.com/neurosnap/zmx";
      platforms = builtins.attrNames sources;
      mainProgram = "zmx";
    };
  };
}
