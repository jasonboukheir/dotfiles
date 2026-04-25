{inputs}: final: prev:
# TODO: drop this overlay once the Nix output-hash rewriting fix lands.
# fish 4.2.1 in nixpkgs-25.11-darwin has an invalid ad-hoc code signature
# because a Nix bug corrupts Mach-O signed code pages.
# https://github.com/NixOS/nixpkgs/issues/507531
# https://github.com/NixOS/nix/pull/15638
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  fish = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.fish;
}
