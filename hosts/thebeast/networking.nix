{
  config,
  pkgs,
  ...
}: let
  wpaSupplicantUnit = pkgs.writeText "wpa_supplicant.service" ''
    [Unit]
    Description=WPA supplicant
    After=dbus.service
    Before=network.target
    Wants=network.target

    [Service]
    Type=dbus
    BusName=fi.w1.wpa_supplicant1
    ExecStart=${pkgs.wpa_supplicant}/sbin/wpa_supplicant -u
  '';
in {
  networking = {
    hostName = "thebeast";
    networkmanager = {
      enable = true;
      # iwd matches Steam Deck upstream and is the default backend. A
      # wpa_supplicant.service is also shipped (in /run, see below) so Big
      # Picture's SetWifiBackend D-Bus call can no-op on the "other"
      # backend without erroring out the switch.
      wifi.backend = "iwd";
    };
  };

  # Ship wpa_supplicant.service via /run/systemd/system instead of through
  # NixOS's normal /etc/systemd/system path. iwd stays the active backend;
  # this unit only exists so steamos-manager's Big-Picture-launched
  # SetWifiBackend(iwd) D-Bus call has the "other" unit to operate on
  # without error.
  #
  # steamos-manager v26.1.0 wifi.rs:359 calls `disable_unit_files(
  # ["wpa_supplicant.service"], runtime=false)` before restarting
  # NetworkManager. On NixOS, anything declared via `systemd.services` or
  # `systemd.packages` ends up symlinked under /etc/systemd/system, which
  # is itself a symlink through /etc/static into the read-only
  # system-units derivation in /nix/store. systemd reports the unit as
  # `UnitFileState=linked` and tries to unlink the symlink to disable it;
  # the unlink resolves into /nix/store and fails with EROFS, aborting
  # the D-Bus call before NM is restarted, leaving wifi down.
  #
  # Writing the unit into /run/systemd/system (tmpfs) as a regular file at
  # activation time keeps it in systemd's search path but makes it
  # `UnitFileState=static` (no [Install] section, no symlink to unlink), so
  # DisableUnitFiles becomes a no-op success. The activation script runs
  # in stage-2 before systemd is exec'd on boot, and again on every
  # `nixos-rebuild switch`, so the file is in place before any unit scan.
  # The dbus activation file ships SystemdService=wpa_supplicant.service,
  # so NetworkManager can still pull this unit via D-Bus if the user ever
  # toggles the backend.
  # TODO: drop if steamos-manager learns to tolerate EROFS on the other
  # backend — https://github.com/Jovian-Experiments/steamos-manager/blob/main/steamos-manager/src/wifi.rs
  system.activationScripts.wpaSupplicantRuntimeUnit = ''
    mkdir -p /run/systemd/system
    install -m 0644 ${wpaSupplicantUnit} /run/systemd/system/wpa_supplicant.service
  '';
  services.dbus.packages = [pkgs.wpa_supplicant];

  # dbus-broker logs a warning at startup because the wpa_supplicant dbus
  # policy file references `group="wpa_supplicant"` for an extra send/own
  # allowance. The group isn't required (the service runs as root) but
  # creating it silences the noise and matches what Debian/Arch ship.
  users.groups.wpa_supplicant = {};

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
