{ pkgs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.jasonbk.home = {
      stateVersion = "24.05";
      packages = with pkgs; [
        kitty
        neovim
        (nerdfonts.override { fonts = [ "FiraCode" ]; })
      ];
    };
  };
}
