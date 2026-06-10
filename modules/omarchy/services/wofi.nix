# wofi has no daemon — Hyprland keybindings spawn it — so unlike its siblings
# here this only enables the my.* wrapper and ports the launcher defaults from
# the retired home-manager module (issue #48).
{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    my.wofi.enable = lib.mkDefault true;
    my.wofi.settings = {
      width = 600;
      height = 350;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };
  };
}
