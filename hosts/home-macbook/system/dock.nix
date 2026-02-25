{config, pkgs, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      config.homebrewCasks.brave.appPath
      "${pkgs.ghostty-bin}/Applications/Ghostty.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
