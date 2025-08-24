{pkgs, ...}: {
  environment.systemPackages = with pkgs; [electrum];
}
