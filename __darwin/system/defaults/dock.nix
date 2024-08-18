{ pkgs, pkgs-zed-fix, ... }:
let
  # for modifier support, check https://github.com/LnL7/nix-darwin/issues/998
  modifiers = {
    none = 0;
    option = 524288;
    cmd = 1048576;
    "option+cmd" = 1573864;
  };
in
{
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    orientation = "right";
    persistent-apps = [
      "/System/Cryptexes/App/System/Applications/Safari.app"
      "${pkgs.kitty}/Applications/kitty.app"
      "${pkgs-zed-fix.zed-editor}/Applications/Zed.app"
      "/Applications/Godot.app"
      "/System/Applications/Messages.app"
      "/System/Applications/Mail.app"
      "/System/Applications/Music.app"
    ];
    show-recents = false;
    wvous-tr-corner = 13;
    wvous-br-corner = 14;
  };
  system.defaults.CustomUserPreferences = {
    "com.apple.Dock" = {
      wvous-tl-modifier = modifiers.cmd;
      wvous-bl-modifier = modifiers.cmd;
      wvous-tr-modifier = modifiers.cmd;
      wvous-br-modifier = modifiers.cmd;
    };
  };
}