{ inputs, ... }:
{
  home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
}
