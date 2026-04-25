{
  description = "jasonbk's mono-flake (NixOS + nix-darwin + home-manager).";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixos";
    };

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

    nvf-nixos = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixos";
    };
    nvf-nixos-unstable = {
      url = "github:notashelf/nvf/main";
      inputs.nixpkgs.follows = "nixos-unstable";
    };
    nvf-darwin = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
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
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      imports = [
        inputs.flake-parts.flakeModules.partitions
        ./modules/flake
      ];
    };
}
