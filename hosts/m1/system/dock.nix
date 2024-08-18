{ inputs, pkgs, ... }:
let
  pkgs-zed-fix = inputs.nixpkgs-zed-fix.legacyPackages.${pkgs.system};
in
{
  system.defaults.dock = {
    persistent-apps = [
      "/System/Cryptexes/App/System/Applications/Safari.app"
      "${pkgs.kitty}/Applications/kitty.app"
      "${pkgs-zed-fix.zed-editor}/Applications/Zed.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
