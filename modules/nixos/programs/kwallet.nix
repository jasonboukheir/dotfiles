{
  config,
  lib,
  pkgs,
  ...
}: {
  # Upstream kwallet installs activation files for
  # org.kde.secretservicecompat but not org.freedesktop.secrets.
  # In a Plasma session something pokes secretservicecompat at
  # startup and ksecretd then claims both names; in a non-Plasma
  # session (e.g. Hyprland) nothing does, so libsecret clients
  # hang on the freedesktop name. ksecretd already claims it once
  # activated — we just need an activation file pointing at the
  # same binary.
  # TODO: drop once upstream ships the file.
  # https://invent.kde.org/frameworks/kwallet/-/merge_requests/97
  # https://invent.kde.org/frameworks/kwallet/-/raw/master/src/runtime/ksecretd/CMakeLists.txt
  config = lib.mkIf config.services.desktopManager.plasma6.enable {
    services.dbus.packages = [
      (pkgs.writeTextDir "share/dbus-1/services/org.freedesktop.secrets.service" ''
        [D-BUS Service]
        Name=org.freedesktop.secrets
        Exec=${pkgs.kdePackages.kwallet}/bin/ksecretd
      '')
    ];
  };
}
