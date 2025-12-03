{pkgs, ...}: {
  boot.initrd.kernelModules = ["amdgpu"];

  services.xserver = {
    enable = true;
    videoDrivers = ["amdgpu"];
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
