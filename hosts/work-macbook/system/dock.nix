{config, pkgs, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      config.homebrewCasks.brave.appPath
      "${pkgs.ghostty-bin}/Applications/Ghostty.app"
      "/Applications/VS Code @ FB.app"
    ];
  };
}
