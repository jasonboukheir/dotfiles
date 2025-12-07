{...}: {
  hardware.amdgpu.initrd.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = ["amdgpu" "modesetting"];
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
