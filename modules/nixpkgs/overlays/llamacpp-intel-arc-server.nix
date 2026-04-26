{inputs}: final: prev: let
  unstable = import inputs.nixpkgs-unstable {
    localSystem = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in {
  llamacpp-intel-arc-server = final.callPackage ../../../pkgs/llamacpp-intel-arc-server {
    inherit (unstable.intel-oneapi) base;
    inherit (unstable) onednn;
  };
}
