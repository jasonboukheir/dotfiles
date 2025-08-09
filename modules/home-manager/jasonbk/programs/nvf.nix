{ config, lib, ... }:
{
  config.programs.nvf.enable = lib.mkDefault true;
}
