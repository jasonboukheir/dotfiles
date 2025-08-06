{
  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nvf = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:notashelf/nvf";
    };
  };

  outputs =
    inputs@{
      home-manager,
      mac-app-util,
      nix-darwin,
      nix-homebrew,
      nixpkgs,
      ...
    }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations =
        let
          darwinSpecialArgs = {
            inherit inputs;
            system = "aarch64-darwin";
          };
          darwinModules = [
            mac-app-util.darwinModules.default
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
          ];
        in
        {
          "Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
            specialArgs = darwinSpecialArgs;
            modules = darwinModules ++ [
              ./hosts/home-macbook
            ];
          };
          "jasonbk-mac" = nix-darwin.lib.darwinSystem {
            specialArgs = darwinSpecialArgs;
            modules = darwinModules ++ [
              ./hosts/work-macbook
            ];
          };
        };

      nixosConfigurations = {
        brutus = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            home-manager.nixosModules.home-manager
            ./hosts/brutus
          ];
        };
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
}
