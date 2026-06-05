{
  config,
  pkgs,
  ...
}: {
  system.defaults.dock = {
    persistent-apps = [
      config.homebrewCasks.brave.appPath
      "${pkgs.ghostty-bin}/Applications/Ghostty.app"
      config.homebrewCasks.element.appPath
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
