{pkgs, ...}: let
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
  hyprlandSessions = "${pkgs.hyprland}/share/wayland-sessions";
in {
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${tuigreet} --time --remember --remember-session --sessions ${hyprlandSessions}";
        user = "greeter";
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardError = "journal";
  };
}
