{...}: {
  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  services.lact.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = ["amdgpu" "modesetting"];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
