{
  partitions.darwin = {
    extraInputsFlake = ./.;
    module = {inputs, ...}: {
      flake.darwinConfigurations = let
        # neovimConfiguration is the specialArg my.nvf builds neovim from;
        # pin the nvf input whose nixpkgs matches these hosts' channel.
        specialArgs = {
          inherit inputs;
          neovimConfiguration = inputs.nvf-darwin.lib.neovimConfiguration;
        };
        # Modules every darwin host gets. home-manager is opt-in per host
        # (mkHost's `homeManager` arg) so home-manager-free hosts (work-macbook,
        # #55) never pull the module in.
        sharedModules = [
          inputs.mac-app-util.darwinModules.default
          inputs.nix-homebrew.darwinModules.nix-homebrew
          inputs.stylix-darwin.darwinModules.stylix
        ];
        mkHost = {
          hostPath,
          homeManager ? true,
        }:
          inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            inherit specialArgs;
            modules =
              sharedModules
              ++ inputs.nixpkgs-darwin.lib.optional homeManager inputs.home-manager-darwin.darwinModules.home-manager
              ++ [hostPath];
          };
      in {
        "Jasons-MacBook-Pro" = mkHost {hostPath = ../../../hosts/home-macbook;};
        "jasonbk-mac" = mkHost {
          hostPath = ../../../hosts/work-macbook;
          homeManager = false;
        };
      };
    };
  };

  partitionedAttrs.darwinConfigurations = "darwin";
}
