{pkgs, ...}: {
  environment.systemPackages = with pkgs; [tor];
}
