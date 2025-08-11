{ ... }:
{
  programs.nushell = {
    enable = true;
    envFile.source = ./env.nu;
  };
}
