{ system, config, ... }:
{
  home-manager = {
    extraSpecialArgs = {
      inherit system;
      systemConfig = config;
    };
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
