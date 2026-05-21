{...}: {
  imports = [./session];

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
