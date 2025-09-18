{pkgs, ...}: {
  environment.systemPackages = [pkgs.zfs];
}
