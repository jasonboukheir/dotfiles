{
  inputs = {
    nix-bitcoin = {
      url = "github:fort-nix/nix-bitcoin/release";
    };
    nixpkgs.follows = "nix-bitcoin/nixpkgs";
    nixpkgs-unstable.follows = "nix-bitcoin/nixpkgs-unstable";
    nvf = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:notashelf/nvf";
    };
  };

  outputs = inputs @ {
    nix-bitcoin,
    nixpkgs,
    ...
  }: {
    nixosConfigurations.pibitcoin = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        nix-bitcoin.nixosModules.default
        (nix-bitcoin + "/modules/presets/secure-node.nix")
        ./default.nix
      ];
    };
    nix.nixPath = ["nixpkgs=${nixpkgs}"];
  };
}
