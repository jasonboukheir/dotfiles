{
  partitions.home = {
    module = {inputs, ...}: {
      flake.homeConfigurations."jasonbk@work-devserver" = inputs.home-manager-nixos.lib.homeManagerConfiguration {
        pkgs = import inputs.nixos {
          system = "x86_64-linux";
          config.allowUnfree = true;
          overlays = [
            (import ../../modules/nixpkgs/overlays/zmx.nix)
          ];
        };
        extraSpecialArgs = {
          inherit inputs;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
        modules = [
          ../../hosts/work-devserver
          inputs.nvf-nixos.homeManagerModules.default
          inputs.stylix-nixos.homeManagerModules.stylix
        ];
      };
    };
  };

  partitionedAttrs.homeConfigurations = "home";
}
