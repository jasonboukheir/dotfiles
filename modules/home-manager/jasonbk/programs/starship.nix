{ config, lib, ... }:
{
  programs.starship.enable = lib.mkDefault true;
}
