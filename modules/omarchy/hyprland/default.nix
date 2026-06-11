# Hyprland's own config, generated at the NixOS layer into the my.hyprland
# wrapper (issues #40/#48) — replaces modules/omarchy/home-manager/hyprland.
# Everything here is per-session state: hyprland.lua only takes effect inside
# a Hyprland session, so the single system-scope config is safe for every
# user — both jasonbk and gamer run this same Hyprland session.
# my.hyprland.enable stays off: programs.hyprland already installs the
# wrapper (via programs.nix), and enabling it here would additionally
# install the un-hidden session entry next to the NoDisplay one.
{...}: {
  imports = [
    ./autostart.nix
    ./bindings.nix
    ./defaultApps.nix
    ./envs.nix
    ./input.nix
    ./looknfeel.nix
    ./monitor.nix
    ./windows.nix
  ];
}
