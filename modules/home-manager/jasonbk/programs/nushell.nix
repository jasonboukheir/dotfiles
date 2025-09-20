{lib, ...}:
with lib; {
  programs.nushell = {
    enable = mkDefault true;
  };
}
