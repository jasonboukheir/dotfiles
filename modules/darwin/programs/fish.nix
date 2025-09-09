{lib, ...}: {
  programs.fish = {
    enable = lib.mkDefault true;
  };
}
