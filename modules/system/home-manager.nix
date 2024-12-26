{ ghostty, ... }:
{
  home-manager = {
    sharedModules = [

    ];
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jasonbk.home = {
      stateVersion = "24.05";
    };
  };
}
