{pkgs, ...}: {
  environment.systemPackages = with pkgs; [dotnet-sdk];
  environment.variables = with pkgs; {
    DOTNET_ROOT = "${dotnet-sdk}/share/dotnet";
  };
}
