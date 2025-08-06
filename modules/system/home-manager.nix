{ system, ... }:
{
  home-manager = {
    extraSpecialArgs = { inherit system; };
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
