{pkgs, ...}: {
  omarchy.enable = true;
  omarchy.pim = "gnome";

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --sessions /run/current-system/sw/share/wayland-sessions --remember-user-session";
        user = "greeter";
      };
    };
  };

  home-manager.users.jasonbk.imports = [../../home-manager/jasonbk];
}
