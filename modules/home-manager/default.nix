{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    ./jasonbk
    ./sharedModules
  ];

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
}
