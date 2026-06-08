{inputs, ...}: {
  imports = [
    inputs.helium-flake.nixosModules.default
  ];

  nixpkgs.overlays = [
    inputs.helium-flake.overlays.default
  ];

  programs.helium = {
    enable = true;
    policies.ExtensionInstallForcelist = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
      "dphilobhebphkdjbpfohgikllaljmgbn"
    ];
  };
}
