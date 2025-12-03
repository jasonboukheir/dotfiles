{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    agenix.url = "github:ryantm/agenix";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixos";
    };
    home-manager-nixos = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos";
    };
    home-manager-darwin = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
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
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nixarr.url = "github:rasmus-kirk/nixarr";
    nixcord.url = "github:kaylorben/nixcord";
    nvf-nixos = {
      inputs.nixpkgs.follows = "nixos";
      url = "github:notashelf/nvf/v0.8";
    };
    nvf-darwin = {
      inputs.nixpkgs.follows = "nixpkgs-darwin";
      url = "github:notashelf/nvf/v0.8";
    };
    stylix-nixos = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixos";
    };
    stylix-darwin = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixos";
    };
    omarchy-nix = {
      url = "github:henrysipp/omarchy-nix";
      inputs.nixpkgs.follows = "nixos";
      inputs.home-manager.follows = "home-manager-nixos";
    };
  };

  outputs = inputs @ {
    agenix,
    determinate,
    disko,
    home-manager-nixos,
    home-manager-darwin,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nixarr,
    nixos,
    nixpkgs,
    stylix-nixos,
    stylix-darwin,
    jovian,
    omarchy-nix,
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
        home-manager-darwin.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
        stylix-darwin.darwinModules.stylix
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
      thebeast = nixos.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/thebeast
          agenix.nixosModules.default
          determinate.nixosModules.default
          disko.nixosModules.disko
          home-manager-nixos.nixosModules.home-manager
          stylix-nixos.nixosModules.stylix
          jovian.nixosModules.default
          omarchy-nix.nixosModules.default
        ];
      };

      brutus = nixos.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/brutus
          agenix.nixosModules.default
          determinate.nixosModules.default
          disko.nixosModules.disko
          home-manager-nixos.nixosModules.home-manager
          nixarr.nixosModules.default
          stylix-nixos.nixosModules.stylix
        ];
      };

      litus = nixos.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/litus
          agenix.nixosModules.default
          determinate.nixosModules.default
          home-manager-nixos.nixosModules.home-manager
          stylix-nixos.nixosModules.stylix
        ];
      };
    };

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = import ./shell.nix {
        inherit pkgs;
        inherit agenix;
      };
    });
  };
}
