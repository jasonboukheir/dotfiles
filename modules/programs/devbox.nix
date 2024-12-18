{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ devbox ];
}
