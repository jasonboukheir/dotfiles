{ inputs, pkgs, ... }:
let
  pkgs-zed-fix = inputs.nixpkgs-zed-fix.legacyPackages.${pkgs.system};
in
{
  home-manager.users.jasonbk = {
    home.packages = [ pkgs-zed-fix.zed-editor ];
    home.file = {
      ".config/zed" = {
        source = ./zed;
        recursive = true;
      };
    };
  };
}
