{pkgs, ...}:
pkgs.testers.nixosTest {
  name = "litus-homelab-import";

  # Regression guard for the litus use case: a host imports the homelab
  # settings layer (`modules/homelab`) purely to reference settings —
  # domain, ports, the service registry and its computed domains —
  # WITHOUT hosting anything and WITHOUT the service-provider flake
  # inputs (ezmtls, ...) that the hosting host carries. The settings
  # layer must therefore resolve against plain nixpkgs alone: if an
  # implementation module ever leaked back into it, this node would fail
  # to evaluate (e.g. an undeclared `services.ezmtls`). A successful VM
  # build is the assertion.
  nodes.machine = {...}: {
    imports = [
      ../../../modules/homelab
    ];

    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "25.05";
  };

  testScript = ''
    # Reaching multi-user.target means the full system closure — built
    # from a config that imports the homelab settings layer with no
    # service inputs — evaluated and booted. That is the whole assertion.
    machine.wait_for_unit("multi-user.target")
  '';
}
