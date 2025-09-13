{
  inputs = {
    nix-bitcoin = {
      url = "github:fort-nix/nix-bitcoin/release";
    };
    nixpkgs.follows = "nix-bitcoin/nixpkgs";
    nixpkgs-unstable.follows = "nix-bitcoin/nixpkgs-unstable";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nix-bitcoin,
    nixos-raspberrypi,
    nixpkgs,
    ...
  }: {
    nixosConfigurations.pibitcoin = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        nix-bitcoin.nixosModules.default
        (nix-bitcoin + "/modules/presets/secure-node.nix")
        ./default.nix
      ];
    };
    nix.nixPath = ["nixpkgs=${nixpkgs}"];
  };
}
