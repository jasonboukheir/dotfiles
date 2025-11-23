{
  inputs = {
    agenix.url = "github:ryantm/agenix";
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
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    agenix,
    determinate,
    disko,
    home-manager,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nixarr,
    nixpkgs,
    stylix,
    ...
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    nixpkgsFor = system: let
      pkgs = import nixpkgs {
        inherit system;
      };
      patchedPkgs = pkgs.applyPatches {
        name = "nixpkgs-patched-${nixpkgs.shortRev}";
        src = nixpkgs;
        patches = [
          # fix for open-webui
          (pkgs.fetchpatch {
            url = "https://github.com/NixOS/nixpkgs/commit/913f7247e73349be04b2badb80f1b2d1730fe4f9.patch";
            sha256 = "sha256-XH6mbixskcZ90KQaFkkRw6CpzRqjkkzBpVWTPZmp03A=";
          })
          (pkgs.fetchpatch {
            url = "https://github.com/NixOS/nixpkgs/commit/218c32dbc8a4109d4687b898a6386588ee30601d.patch";
            sha256 = "sha256-llch1jaqkCMasDOJAjF/sM465S33ZwNDK/N0/SaJYbE=";
          })
        ];
      };
    in
      import patchedPkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
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
        stylix.darwinModules.stylix
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

    nixosConfigurations = let
      pkgs = nixpkgsFor "x86_64-linux";
    in {
      brutus = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ({...}: {nixpkgs.pkgs = pkgs;})
          ./hosts/brutus
          agenix.nixosModules.default
          determinate.nixosModules.default
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          nixarr.nixosModules.default
          stylix.nixosModules.stylix
        ];
      };

      litus = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ({...}: {nixpkgs.pkgs = pkgs;})
          ./hosts/litus
          agenix.nixosModules.default
          determinate.nixosModules.default
          home-manager.nixosModules.home-manager
          stylix.nixosModules.stylix
        ];
      };
    };
    nix.nixPath = ["nixpkgs=${nixpkgs}"];

    devShells = forAllSystems (system: let
      pkgs = nixpkgsFor system;
    in {
      default = import ./shell.nix {
        inherit pkgs;
        inherit agenix;
      };
    });
  };
}
