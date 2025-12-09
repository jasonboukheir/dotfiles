{...}: {
  wayland.windowManager.hyprland.enable = true;
  services.hyprpolkitagent.enable = true;
  imports = [
    ./autostart.nix
    ./bindings.nix
    ./defaultApps.nix
    ./envs.nix
    ./input.nix
    ./looknfeel.nix
    ./windows.nix
  ];
}
