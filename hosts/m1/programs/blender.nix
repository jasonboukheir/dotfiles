{ pkgs-stable, ... }:
{
  # doesn't work!
  home-manager.users.jasonbk = {
    home.packages = [ pkgs-stable.blender ];
  };
}
