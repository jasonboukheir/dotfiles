{lib, ...}: {
  programs.man.generateCaches = lib.mkForce false;
}
