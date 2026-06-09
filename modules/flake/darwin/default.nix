{
  partitions.darwin = {
    extraInputsFlake = ./.;
    module = {inputs, ...}: {
      flake.darwinConfigurations = let
        # neovimConfiguration is the specialArg my.nvf builds neovim from; the
        # native programs.nvf module takes the same builder via programs.nvf.
        specialArgs = {
          inherit inputs;
          neovimConfiguration = inputs.nvf-darwin.lib.neovimConfiguration;
        };
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
