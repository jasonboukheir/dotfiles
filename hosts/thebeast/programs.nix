{
  config,
  options,
  lib,
  pkgs,
  ...
}: {
  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      customAllowedBrowsers =
        lib.optional (options.programs ? helium && config.programs.helium.enable) "helium";
    };
  };
  environment.systemPackages = with pkgs; [
    vlc
  ];
}
