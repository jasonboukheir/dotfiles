{ pkgs, ... }:
{
  homebrew.casks = [ "unity-hub" ];
  environment.systemPackages = with pkgs; [ dotnet-sdk ];
}
