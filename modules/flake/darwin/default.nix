{
  partitions.darwin = {
    extraInputsFlake = ./.;
    module = {inputs, ...}: {
      flake.darwinConfigurations = let
        specialArgs = {inherit inputs;};
        sharedModules = [
          inputs.mac-app-util.darwinModules.default
          inputs.home-manager-darwin.darwinModules.home-manager
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.stylix-darwin.darwinModules.stylix
        ];
        mkHost = hostPath:
          inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            inherit specialArgs;
            modules = sharedModules ++ [hostPath];
          };
      in {
        "Jasons-MacBook-Pro" = mkHost ../../../hosts/home-macbook;
        "jasonbk-mac" = mkHost ../../../hosts/work-macbook;
      };
    };
  };

  partitionedAttrs.darwinConfigurations = "darwin";
}
