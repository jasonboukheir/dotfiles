{lib, ...}: {
  # getting hangs: https://github.com/direnv/direnv/issues/755
  programs.direnv = {
    enable = lib.mkDefault false;
  };
}
