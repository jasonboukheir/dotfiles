{ pkgs, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "/System/Cryptexes/App/System/Applications/Safari.app"
      "System/Applications/Ghostty.app"
      "${pkgs.zed-editor}/Applications/Zed.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
