{
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    nixarr.url = "github:rasmus-kirk/nixarr";
    nixcord.url = "github:kaylorben/nixcord";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nvf = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:notashelf/nvf";
    };
    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };
  };

  outputs = inputs @ {
    determinate,
    disko,
    home-manager,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nixarr,
    nixpkgs,
    sops-nix,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
  in {
    # Build darwin flake using:
    # $ darwin-rebuild switch --flake .
    darwinConfigurations = let
      specialArgs = {
        inherit inputs;
      };
      darwinModules = [
        mac-app-util.darwinModules.default
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
      ];
    in {
      "Jasons-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = specialArgs;
        modules =
          darwinModules
          ++ [
            ./hosts/home-macbook
          ];
      };
      "jasonbk-mac" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = specialArgs;
        modules =
          darwinModules
          ++ [
            ./hosts/work-macbook
          ];
      };
    };

    nixosConfigurations = {
      brutus = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          determinate.nixosModules.default
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          nixarr.nixosModules.default
          sops-nix.nixosModules.sops
          ./hosts/brutus
        ];
      };
    };
    nix.nixPath = ["nixpkgs=${nixpkgs}"];

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = import ./shell.nix {inherit pkgs;};
    });
  };
}
