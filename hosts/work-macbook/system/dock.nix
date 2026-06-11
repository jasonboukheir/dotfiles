{config, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      config.homebrewCasks.brave.appPath
      "${config.users.users.jasonbk.my.ghostty.finalPackage}/Applications/Ghostty.app"
      "/Applications/VS Code @ FB.app"
    ];
  };
}
