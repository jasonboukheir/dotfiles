{...}: {
  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  services.lact = {
    enable = true;
    settings = {
      daemon.log_level = "info";
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
