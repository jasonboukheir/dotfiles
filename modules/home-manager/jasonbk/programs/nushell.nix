{lib, ...}: with lib; {
  programs.nushell = {
    enable = mkDefault true;
    vivid = {
      enable = mkDefault true;
      theme = mkDefault "nord";
    };
  };
}
