{lib, ...}: {
  programs.fish = {
    enable = lib.mkDefault true;
    useBabelfish = lib.mkDefault true;
  };
}
