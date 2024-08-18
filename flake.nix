{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Won't be fixed until this PR is merged https://github.com/NixOS/nixpkgs/pull/329653
    nixpkgs-zed-fix.url = "github:nixos/nixpkgs?ref=1bdad05edc5e154935176aab4a3412e29b351d3f";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
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
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nixpkgs-zed-fix,
      home-manager,
      nix-homebrew,
      homebrew-bundle,
      homebrew-cask,
      homebrew-core,
    }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations."Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/m1
        ];
      };
      darwinConfigurations."jasonbk-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/m3
        ];
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
}
