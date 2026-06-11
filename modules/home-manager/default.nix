{
  inputs,
  pkgs,
  config,
  lib,
  options,
  ...
}: {
  imports = [
    ./jasonbk
    ./sharedModules
  ];

  # The home-manager module is absent on home-manager-free hosts (thebeast,
  # #57). Guard on the option existing so this shared per-user config stays
  # inert there while macs/servers keep their home-manager generations.
  config = lib.optionalAttrs (options ? home-manager) {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
      extraSpecialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit (pkgs.stdenv.hostPlatform) system;
          inherit (config.nixpkgs) config;
        };
      };
    };
  };
}
