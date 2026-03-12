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
      ./hypridle.nix
      ./mako.nix
      ./waybar.nix
      ./wofi.nix
    ]
    ++ lib.optionals (config.omarchy.enable && config.omarchy.macKeybindings.enable) [
      ./keyd.nix
    ];
}
