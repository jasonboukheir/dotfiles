{
  inputs,
  pkgs,
  config,
  ...
}: {
  home-manager.extraSpecialArgs = {
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit (pkgs.stdenv.hostPlatform) system;
      inherit (config.nixpkgs) config;
    };
  };
}
