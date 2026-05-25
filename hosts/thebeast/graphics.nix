{...}: {
  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  services.lact = {
    enable = true;
    settings = {
      # pin schema version to skip startup migration; the config file is a
      # read-only /nix/store symlink, so a migration save would fail with EROFS.
      # bump in lockstep with lact's CURRENT_VERSION on package upgrades.
      version = 5;
      daemon = {
        log_level = "info";
        # socket is chowned to this group; without it the daemon falls back to
        # its own gid (root) and non-root users get EACCES connecting.
        admin_group = "wheel";
      };
      gpus."1002:7550-1DA2:E490-0000:03:00.0" = {
        power_cap = 304.0;
        voltage_offset = -10;
        fan_control_enabled = true;
        fan_control_settings = {
          mode = "curve";
          temperature_key = "edge";
          interval_ms = 500;
          curve = {
            "40" = 0.30;
            "55" = 0.50;
            "65" = 0.70;
            "75" = 0.90;
            "85" = 1.00;
          };
        };
      };
    };
  };

  services.xserver = {
    enable = true;
    videoDrivers = ["amdgpu" "modesetting"];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
