{ pkgs, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "${pkgs.brave}/Applications/Brave Browser.app"
      "/Applications/Ghostty.app"
      "${pkgs.zed-editor}/Applications/Zed.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
