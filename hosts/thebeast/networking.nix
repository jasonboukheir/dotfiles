{config, ...}: {
  networking = {
    hostName = "thebeast";
    networkmanager = {
      enable = true;
      # iwd matches Steam Deck upstream; Jovian's steamos-manager patch
      # already resolves the iwd binary out of the Nix store, so the
      # switch-backend D-Bus call from Big Picture works without extra
      # plumbing. Setting the NixOS option here flips NM and brings up
      # iwd.service automatically.
      wifi.backend = "iwd";
    };
  };

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
