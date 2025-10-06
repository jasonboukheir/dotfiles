{pkgs, ...}: {
  environment.systemPackages = [pkgs.tor];
}
