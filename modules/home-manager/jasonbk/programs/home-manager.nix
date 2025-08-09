{ config, lib, ... }:
{
  config.programs.home-manager.enable = lib.mkDefault true;
}
