{...}: {
  imports = [
    ./sharedModules
  ];
  home-manager.users.jasonbk.imports = [./jasonbk];
  home-manager.users.gamer.imports = [
    ./gamer
    # The omarchy HM sharedModules apply to every user by default;
    # gamer runs Plasma, so opt out of the whole Hyprland stack via
    # the per-user toggle. Without this, hyprpolkitagent.service
    # would start inside the Plasma session and core-dump on the
    # missing Qt platform plugin, and waybar/hypridle/etc would leave
    # stale unit symlinks under ~/.config/systemd/user/.
    {omarchy.enable = false;}
  ];
}
