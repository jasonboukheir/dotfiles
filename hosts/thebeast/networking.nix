{
  config,
  pkgs,
  ...
}: {
  networking = {
    hostName = "thebeast";
    networkmanager = {
      enable = true;
      # iwd matches Steam Deck upstream and is the default backend. The
      # wpa_supplicant.service unit is also shipped (see systemd.packages
      # below) so Big Picture's wifi-backend toggle can flip between them.
      wifi.backend = "iwd";
    };
  };

  # Ship wpa_supplicant alongside iwd, matching SteamOS upstream. The unit
  # is D-Bus-activated (Type=dbus, BusName=fi.w1.wpa_supplicant1) and only
  # comes up if NM asks for it, so iwd stays the active backend until the
  # user flips the toggle in Steam Big Picture.
  #
  # Without this, steamos-manager's SetWifiBackend D-Bus call — which Big
  # Picture fires on launch — stops NetworkManager first, then errors with
  # `NoSuchUnit: wpa_supplicant.service does not exist` while trying to
  # stop the opposite backend, leaving NM dead and wifi unreachable until
  # manual intervention.
  #
  # The NM NixOS module excludes wpa_supplicant from its package list when
  # `wifi.backend = "iwd"`, so we wire the systemd unit and D-Bus policy /
  # activation files in ourselves.
  # TODO: drop if steamos-manager learns to tolerate a missing opposite
  # backend — https://github.com/Jovian-Experiments/steamos-manager/blob/main/steamos-manager/src/wifi.rs
  systemd.packages = [pkgs.wpa_supplicant];
  services.dbus.packages = [pkgs.wpa_supplicant];

  # steamos-manager's GetWifiBackend scans /etc/NetworkManager/conf.d/*.conf
  # for `[device] wifi.backend=...` and errors on every D-Bus call when
  # the key is absent. NixOS's networking.networkmanager.wifi.backend
  # writes to NetworkManager.conf, which steamos-manager doesn't read;
  # mirror the value into conf.d so the canonical NixOS option stays the
  # single source of truth.
  # TODO: drop if steamos-manager learns to fall back to NM's default —
  # https://github.com/Jovian-Experiments/steamos-manager/blob/main/steamos-manager/src/wifi.rs
  environment.etc."NetworkManager/conf.d/10-wifi-backend.conf".text = ''
    [device]
    wifi.backend=${config.networking.networkmanager.wifi.backend}
  '';
}
