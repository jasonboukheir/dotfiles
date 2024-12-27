{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util.url = "github:hraban/mac-app-util";
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
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty.url = "github:ghostty-org/ghostty";
    ghostty-hm.url = "github:clo4/ghostty-hm-module";
  };

  outputs =
    inputs@{
      nix-darwin,
      nixpkgs,
      home-manager,
      nix-homebrew,
      mac-app-util,
      ...
    }:
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
      # Build darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations."Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = darwinSpecialArgs;
        modules = darwinModules ++ [
          ./hosts/m1
        ];
      };
      darwinConfigurations."jasonbk-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = darwinSpecialArgs;
        modules = darwinModules ++ [
          ./hosts/m3
        ];
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
}
