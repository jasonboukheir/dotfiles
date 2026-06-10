{pkgs, ...}: {
  # Stylix sets gtk-theme-name but not gtk-icon-theme-name, so GTK
  # falls back to hicolor — which has no app icons, leaving wofi's
  # drun list as text-only. Pin breeze-dark (already pulled in by the
  # KDE stack on thebeast for the gamer session) so the launcher can
  # resolve icons. Only takes effect where stylix's gtk target keeps
  # gtk.enable on; gamer disables that target so Plasma's GTK Settings
  # Sync owns the files instead (see hosts/thebeast/home-manager/gamer).
  gtk.iconTheme = {
    package = pkgs.kdePackages.breeze-icons;
    name = "breeze-dark";
  };
}
