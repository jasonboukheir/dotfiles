{inputs}: final: prev:
# Workaround for https://github.com/NixOS/nixpkgs/issues/507531
# The fish 4.2.1 binary shipped in nixpkgs-25.11-darwin has an invalid ad-hoc
# code signature due to a Nix output-hash rewriting bug that corrupts Mach-O
# signed code pages (tracked upstream in https://github.com/NixOS/nix/pull/15638).
# Pull fish from nixpkgs-unstable on darwin until the upstream fix lands.
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  fish = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.fish;
}
