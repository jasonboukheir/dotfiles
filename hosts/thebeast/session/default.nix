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

  # SDDM, per the #48 session-redesign plan: strictly less KDE than
  # plasma-login-manager (PLM is a Plasma-coupled SDDM fork), and the
  # UWSM/hyprland-uwsm path (#40) is only documented against SDDM.
  # Jovian already forces sddm.wayland.enable, so the Wayland greeter
  # is status quo. The greeter-recycle-after-logout lifecycle is gated
  # by tests/dm-recovery.nix. PLM stays one flag away if SDDM regresses.
  thebeast.displayManager = "sddm";

  gaming.enable = true;
  gaming.bigPicture.enable = true;
  gaming.roms.enable = true;
}
