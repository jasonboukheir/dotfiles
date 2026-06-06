{
  partitions.nixos = {
    extraInputsFlake = ../../nixos;
    module = {inputs, ...}: {
      flake.nixosConfigurations = {
        thebeast = inputs.nixos-unstable.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [
            ../../hosts/thebeast
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos-unstable.nixosModules.home-manager
            inputs.stylix-nixos-unstable.nixosModules.stylix
            inputs.jovian.nixosModules.default
          ];
        };

        brutus = inputs.nixos.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
            pkgs-unstable = import inputs.nixpkgs-unstable {
              localSystem = "x86_64-linux";
              config.allowUnfree = true;
            };
            terranix = inputs.terranix;
          };
          modules = [
            ../../hosts/brutus
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos.nixosModules.home-manager
            inputs.nixarr.nixosModules.default
            inputs.stylix-nixos.nixosModules.stylix
            inputs.ezmtls.nixosModules.default
            inputs.vllm-xpu-nix.nixosModules.default
          ];
        };

        litus = inputs.nixos.lib.nixosSystem {
          specialArgs = {inherit inputs;};
          modules = [
            ../../hosts/litus
            inputs.agenix.nixosModules.default
            inputs.determinate.nixosModules.default
            inputs.home-manager-nixos.nixosModules.home-manager
            inputs.stylix-nixos.nixosModules.stylix
          ];
        };
      };

      perSystem = {system, ...}:
      # nixosTest only runs on Linux; gate so darwin systems still evaluate.
        if system != "x86_64-linux"
        then {}
        else let
          pkgs = import inputs.nixos-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          # brutus pins inputs.nixos (the stable channel), so its tests must
          # run on the same nixpkgs the host evaluates under — otherwise the
          # rendered homeserver.yaml / unit files in the test diverge from
          # what we'd actually ship.
          brutusPkgs = import inputs.nixos {
            inherit system;
            config.allowUnfree = true;
          };
        in {
          checks.thebeast-session = import ../../hosts/thebeast/tests/session.nix {
            inherit pkgs inputs;
          };
          checks.thebeast-dm-recovery = import ../../hosts/thebeast/tests/dm-recovery.nix {
            inherit pkgs inputs;
          };
          checks.thebeast-keyring = import ../../hosts/thebeast/tests/keyring.nix {
            inherit pkgs inputs;
          };
          checks.thebeast-hm-stale-kvantum = import ../../hosts/thebeast/tests/hm-stale-kvantum.nix {
            inherit pkgs inputs;
          };
          checks.brutus-matrix = import ../../hosts/brutus/tests/matrix.nix {
            pkgs = brutusPkgs;
            inherit inputs;
          };
          checks.brutus-matrix-rtc = import ../../hosts/brutus/tests/matrix-rtc.nix {
            pkgs = brutusPkgs;
            inherit inputs;
          };
          checks.brutus-ntfy = import ../../hosts/brutus/tests/ntfy.nix {
            pkgs = brutusPkgs;
            inherit inputs;
          };
        };
    };
  };

  partitionedAttrs.nixosConfigurations = "nixos";
  partitionedAttrs.checks = "nixos";
  partitionedAttrs.packages = "nixos";
  partitionedAttrs.apps = "nixos";
}
