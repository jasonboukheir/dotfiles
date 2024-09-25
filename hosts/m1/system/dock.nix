{ pkgs, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "/System/Cryptexes/App/System/Applications/Safari.app"
      "${pkgs.kitty}/Applications/kitty.app"
      "/Applications/Zed.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
