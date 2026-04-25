{
  description = "jasonbk's mono-flake (NixOS + nix-darwin + home-manager).";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager-nixos = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos";
    };

    stylix-nixos = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixos";
    };

    nvf-nixos = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixos";
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
