{...}: {
  imports = [
    ./jovian-steam.nix
    ./display-manager.nix
    ./keyring.nix
    ./login-manager-stylix.nix
    ./big-picture.nix
    ./decky.nix
    ./steam-theme.nix
    ./roms.nix
    ./omarchy.nix
  ];

  # KDE's new SDDM-replacement (Plasma 6.6, landed in nixos-unstable
  # Jan 2026). Still upstream-experimental ("works for me" per KDE),
  # but the autoLogin contract is identical to SDDM so the jovian
  # gamer→gamescope autoStart path is unaffected. Flip back to "sddm"
  # if the greeter regresses.
  thebeast.displayManager = "plasma-login-manager";

  gaming.enable = true;
  gaming.bigPicture.enable = true;
  gaming.roms.enable = true;
}
