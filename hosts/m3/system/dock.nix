{ pkgs, ... }:
{
  system.defaults.dock = {
    persistent-apps = [
      "/Applications/Google Chrome.app"
      "/Applications/Ghostty.app"
      "${pkgs.zed-editor}/Applications/Zed.app"
      "/Applications/VS Code @ FB.app"
      "/Applications/Cisco/Cisco Secure Client.app"
    ];
  };
}
