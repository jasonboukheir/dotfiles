# retroarch + steam-rom-manager moved to per-user my.* wrappers (#49) — see
# hosts/thebeast/session/gaming-programs.nix.
{...}: {
  home.stateVersion = "25.11";

  # Plasma's GTK Settings Sync already mirrors the active Plasma
  # color scheme (itself stylix-themed) into ~/.gtkrc-2.0 and
  # ~/.config/gtk-{3,4}.0/settings.ini on every login, which then
  # collides with HM's gtk module on the next rebuild ("would be
  # clobbered by backing up"). Letting Plasma own the GTK files
  # keeps the stylix palette on GTK apps without the fight. See
  # https://github.com/nix-community/stylix/issues/267
  stylix.targets.gtk.enable = false;
}
