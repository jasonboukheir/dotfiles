{ ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jasonbk.home = {
      stateVersion = "25.05";
    };
  };
}
