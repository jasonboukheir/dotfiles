{...}: {
  imports = [
    ./jovian-steam.nix
    ./display-manager.nix
    ./displays.nix
    ./keyring.nix
    ./login-manager-stylix.nix
    ./steam-splash.nix
    ./decky.nix
    ./steam-theme.nix
    ./roms.nix
    ./gaming-programs.nix
    ./omarchy.nix
  ];

  # SDDM is the only display manager, per the #48 session-redesign plan:
  # the UWSM/hyprland-uwsm path (#40) is only documented against SDDM, and
  # jovian already forces sddm.wayland.enable so the Wayland greeter is
  # status quo. The greeter-recycle-after-logout lifecycle is gated by
  # tests/dm-recovery.nix.
  gaming.enable = true;
  gaming.roms.enable = true;
}
