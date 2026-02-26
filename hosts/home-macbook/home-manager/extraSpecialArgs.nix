{
  inputs,
  pkgs,
  config,
  ...
}: {
  home-manager.extraSpecialArgs = {
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit (pkgs) system;
      inherit (config.nixpkgs) config;
    };
  };
}
