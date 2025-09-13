{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs @ {
    nixos-raspberrypi,
    nixpkgs,
    ...
  }: {
    nixosConfigurations.pibitcoin = nixos-raspberrypi.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {inherit inputs;};
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ./configuration.nix
      ];
    };
    nix.nixPath = ["nixpkgs=${nixpkgs}"];
  };
}
