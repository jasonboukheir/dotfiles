{...}: {
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
  };
  services.hyprpolkitagent.enable = true;
  imports = [
    ./apps.nix
    ./autostart.nix
    ./bindings.nix
    ./envs.nix
    ./input.nix
    ./looknfeel.nix
    ./windows.nix
  ];
}
