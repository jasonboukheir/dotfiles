{ pkgs, pkgs-unstable, ... }: {
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.zfs.package = pkgs.zfs_unstable;

  boot.kernelParams = [ "xe.force_probe=e223" ];

  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs-unstable; [
      intel-compute-runtime
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  environment.systemPackages = with pkgs-unstable; [
    intel-gpu-tools
  ];
}
