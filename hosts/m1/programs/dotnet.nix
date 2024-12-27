{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ dotnetCorePackages.dotnet_8.sdk ];
}
