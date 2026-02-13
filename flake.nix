{
  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    home-manager-nixos = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos";
    };
    home-manager-nixos-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixos-unstable";
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
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nixarr.url = "github:rasmus-kirk/nixarr";
    nixcord = {
      inputs.nixpkgs.follows = "nixpkgs-darwin";
      url = "github:FlameFlag/nixcord";
    };
    nvf-nixos = {
      inputs.nixpkgs.follows = "nixos";
      url = "github:notashelf/nvf/v0.8";
    };
    nvf-nixos-unstable = {
      inputs.nixpkgs.follows = "nixos-unstable";
      url = "github:notashelf/nvf/main";
    };
    nvf-darwin = {
      inputs.nixpkgs.follows = "nixpkgs-darwin";
      url = "github:notashelf/nvf/v0.8";
    };
    stylix-nixos = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixos";
    };
    stylix-nixos-unstable = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    stylix-darwin = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS/development";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
  };

  outputs = inputs @ {
    agenix,
    determinate,
    home-manager-nixos,
    home-manager-nixos-unstable,
    home-manager-darwin,
    mac-app-util,
    nix-darwin,
    nix-homebrew,
    nixarr,
    nixos,
    nixos-unstable,
    nixpkgs-unstable,
    stylix-nixos,
    stylix-nixos-unstable,
    stylix-darwin,
    jovian,
    ...
  }: let
    forAllSystems = nixpkgs-unstable.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
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
      thebeast = nixos-unstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/thebeast
          agenix.nixosModules.default
          determinate.nixosModules.default
          home-manager-nixos-unstable.nixosModules.home-manager
          stylix-nixos-unstable.nixosModules.stylix
          jovian.nixosModules.default
        ];
      };

      brutus = nixos.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          pkgs-unstable = import nixpkgs-unstable {system = "x86_64-linux";};
        };
        modules = [
          ./hosts/brutus
          agenix.nixosModules.default
          determinate.nixosModules.default
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
      pkgs = import nixpkgs-unstable {inherit system;};
    in {
      default = import ./shell.nix {
        inherit pkgs;
        inherit agenix;
      };
    });
  };
}
