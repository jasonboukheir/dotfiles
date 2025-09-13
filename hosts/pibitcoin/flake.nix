{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
    };
  };

  outputs = inputs @ {
    nixos-raspberrypi,
    nixpkgs,
    ...
  }: {
    nixosConfigurations.pibitcoin = nixos-raspberrypi.lib.nixosInstaller {
      system = "aarch64-linux";
      specialArgs = inputs;
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        ./configuration.nix
      ];
    };
  };
}
