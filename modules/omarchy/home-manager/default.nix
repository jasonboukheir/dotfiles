{
  config,
  lib,
  ...
}: let
  cfg = config.omarchy;
  modules =
    [
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
    ++ lib.optionals cfg.macKeybindings.enable [./keyd.nix];
in {
  options.omarchy.homeManagerUsers = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = ''
      Users that should receive the Omarchy/Hyprland home-manager stack.

      Modules in this stack (hyprpolkitagent, waybar, hypridle, ...) start
      user systemd services unconditionally, so they crash for non-Hyprland
      sessions. Keep this list to users that actually log into Hyprland.
    '';
  };

  config = lib.mkIf cfg.enable {
    home-manager.extraSpecialArgs = {
      systemConfig.omarchy = cfg;
    };
    home-manager.users = lib.genAttrs cfg.homeManagerUsers (_: {
      imports = modules;
    });
  };
}
