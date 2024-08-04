{ pkgs, ... }:
{
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    orientation = "right";
    persistent-apps = [
      "/System/Cryptexes/App/System/Applications/Safari.app"
      "${pkgs.kitty}/Applications/kitty.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "${pkgs.iina}/Applications/IINA.app"
    ];
    show-recents = false;
    # for modifier support, check https://github.com/LnL7/nix-darwin/issues/998
    wvous-tr-corner = 13;
    wvous-br-corner = 14;
  };
}