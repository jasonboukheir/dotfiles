{pkgs, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      "${pkgs.brave}/Applications/Brave Browser.app"
      "${pkgs.ghostty-bin}/Applications/Ghostty.app"
      "/Applications/VS Code @ FB.app"
    ];
  };
}
