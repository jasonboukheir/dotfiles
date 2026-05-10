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
    };
  };

  partitionedAttrs.nixosConfigurations = "nixos";
}
