{pkgs, ...}: {
  system.defaults.dock = {
    persistent-apps = [
      "${pkgs.brave}/Applications/Brave Browser.app"
      "${pkgs.ghostty-bin}/Applications/Ghostty.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
  };
}
