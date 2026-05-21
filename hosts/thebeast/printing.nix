{pkgs, ...}: {
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      cups-filters
      cups-browsed
    ];
  };

  # cupsd registers every queue's ICC profile with colord on each print;
  # without it, the daemon spams CreateProfile/CreateDevice DBus failures
  # at warning level. Cheap to enable, even if we never actually colour-
  # manage anything.
  services.colord.enable = true;
}
