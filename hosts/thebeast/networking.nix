{
  config,
  pkgs,
  ...
}: {
  networking = {
    hostName = "thebeast";
    networkmanager = {
      enable = true;
      # iwd matches Steam Deck upstream and is the default backend. A
      # static wpa_supplicant.service is also shipped below so Big
      # Picture's SetWifiBackend D-Bus call can no-op on the "other"
      # backend without erroring out the switch.
      wifi.backend = "iwd";
    };
  };

  # Ship wpa_supplicant alongside iwd, matching SteamOS upstream. iwd stays
  # the active backend; this is only here so steamos-manager's Big-Picture-
  # launched SetWifiBackend(iwd) D-Bus call has the "other" unit to operate
  # on without error.
  #
  # steamos-manager v26.1.0 wifi.rs:359 unconditionally calls
  # `wpa_supplicant.service`.disable() via systemd's DisableUnitFiles
  # before stopping NetworkManager. Two NixOS-specific failure modes:
  #
  # 1. Without the unit at all: NoSuchUnit, the D-Bus call aborts before
  #    NM is restarted, wifi stays down.
  # 2. With `systemd.packages = [pkgs.wpa_supplicant]`: the package ships
  #    an [Install] section (WantedBy=multi-user.target,
  #    Alias=dbus-fi.w1.wpa_supplicant1.service) but NixOS doesn't honor it
  #    (no matching .wants symlink), so systemd reports
  #    `UnitFileState=linked` and DisableUnitFiles tries to unlink the
  #    symlink at /etc/systemd/system/wpa_supplicant.service itself. That
  #    path resolves through /etc/systemd/system -> /etc/static/... -> the
  #    read-only system-units derivation in /nix/store, so the unlink
  #    fails with EROFS and the D-Bus call again aborts mid-switch.
  #
  # Defining the unit via `systemd.services` with no wantedBy emits no
  # [Install] section (see nixos/lib/systemd-lib.nix:738), giving the
  # `static` state that stock SteamOS ships — DisableUnitFiles becomes a
  # no-op (no install info to remove, no symlink to unlink), the switch
  # completes, and NM comes back up. The actual `stop()` that follows the
  # disable still runs, and nothing in this config ever enables the unit,
  # so the loss of the disable side-effect is harmless.
  # TODO: drop if steamos-manager learns to tolerate EROFS / static units
  # on the "other backend" — https://github.com/Jovian-Experiments/steamos-manager/blob/main/steamos-manager/src/wifi.rs
  systemd.services.wpa_supplicant = {
    description = "WPA supplicant";
    before = ["network.target"];
    after = ["dbus.service"];
    wants = ["network.target"];
    serviceConfig = {
      Type = "dbus";
      BusName = "fi.w1.wpa_supplicant1";
      ExecStart = "${pkgs.wpa_supplicant}/sbin/wpa_supplicant -u";
    };
  };
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
