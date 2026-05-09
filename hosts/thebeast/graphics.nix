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
        power_cap = 334.0;
        voltage_offset = -80;
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
