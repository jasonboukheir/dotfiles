{
  inputs = {
    ghostty-hm.url = "github:clo4/ghostty-hm-module";
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
    let
      darwinSpecialArgs = {
        inherit inputs;
      };
      darwinModules = [
        mac-app-util.darwinModules.default
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
      ];
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations."Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = darwinSpecialArgs;
        modules = darwinModules ++ [
          ./hosts/home-macbook
        ];
      };
      darwinConfigurations."jasonbk-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = darwinSpecialArgs;
        modules = darwinModules ++ [
          ./hosts/work-macbook
        ];
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
}
