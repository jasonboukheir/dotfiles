final: prev: {
  llamacpp-intel-arc-server = final.callPackage ../../../pkgs/llamacpp-intel-arc-server {
    inherit (final.intel-oneapi) base;
    inherit (final) onednn;
  };
}
