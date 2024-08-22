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
  };
}
