{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util.url = "github:hraban/mac-app-util";
    sops-nix.url = "github:Mic92/sops-nix";
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
  };

  outputs =
    inputs@{
      nix-darwin,
      nixpkgs,
      nixpkgs-stable-darwin,
      home-manager,
      nix-homebrew,
      mac-app-util,
      ...
    }:
    {
      # Build darwin flake using:
      # $ darwin-rebuild switch --flake .
      darwinConfigurations."Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          pkgs-stable = import nixpkgs-stable-darwin {
            system = "aarch64-darwin";
            config.allowUnfree = true;
          };
        };
        modules = [
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/m1
        ];
      };
      darwinConfigurations."jasonbk-mac" = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          pkgs-stable = import nixpkgs-stable-darwin {
            system = "aarch64-darwin";
            config.allowUnfree = true;
          };
        };
        modules = [
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/m3
        ];
      };
      nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
    };
}
