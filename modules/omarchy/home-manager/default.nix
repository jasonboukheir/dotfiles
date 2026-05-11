{
  config,
  lib,
  ...
}: {
  home-manager.extraSpecialArgs = {
    systemConfig.omarchy = config.omarchy;
  };
  home-manager.sharedModules =
    lib.optionals config.omarchy.enable [
      ./calendar
      ./hyprland
      ./btop.nix
      ./clipse.nix
      ./hypridle.nix
      ./hyprlock.nix
      ./hyprsunset.nix
      ./mako.nix
      ./onepassword.nix
      ./waybar.nix
      ./wl-clip-persist.nix
      ./wofi.nix
    ]
    ++ lib.optionals (config.omarchy.enable && config.omarchy.macKeybindings.enable) [
      ./keyd.nix
    ];
}
