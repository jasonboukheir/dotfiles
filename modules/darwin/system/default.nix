{ inputs, ... }:
{
  imports = [
    ./AdLib.nix
    ./darkmode.nix
    ./desktopservices.nix
    ./dock.nix
    ./finder.nix
    ./Safari.nix
    ./screencapture.nix
    ./SoftwareUpdate.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  security.pam.enableSudoTouchIdAuth = true;
  home-manager.sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
  system = {
    # activationScripts are executed every time you boot the system or run `nixos-rebuild` / `darwin-rebuild`.
    activationScripts.postUserActivation.text = ''
      # activateSettings -u will reload the settings from the database and apply them to the current session,
      # so we do not need to logout and login again to make the changes take effect.
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults.NSGlobalDomain = {
      # `defaults read NSGlobalDomain "xxx"`
      "com.apple.swipescrolldirection" = false; # enable natural scrolling(default to true)
      AppleKeyboardUIMode = 3; # Mode 3 enables full keyboard control.
      ApplePressAndHoldEnabled = true; # enable press and hold

      # If you press and hold certain keyboard keys when in a text area, the key’s character begins to repeat.
      # This is very useful for vim users, they use `hjkl` to move cursor.
      # sets how long it takes before it starts repeating.
      InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
      # sets how fast it repeats once it starts.
      KeyRepeat = 3; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)

      NSAutomaticCapitalizationEnabled = false; # disable auto capitalization(自动大写)
      NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution(智能破折号替换)
      NSAutomaticPeriodSubstitutionEnabled = false; # disable auto period substitution(智能句号替换)
      NSAutomaticQuoteSubstitutionEnabled = false; # disable auto quote substitution(智能引号替换)
      NSAutomaticSpellingCorrectionEnabled = false; # disable auto spelling correction(自动拼写检查)
      NSNavPanelExpandedStateForSaveMode = true; # expand save panel by default(保存文件时的路径选择/文件名输入页)
      NSNavPanelExpandedStateForSaveMode2 = true;
    };
  };
}
