# Lua locals the app-launcher bindings dispatch through (see bindings.nix);
# the values come from the system-wide omarchy.defaultApps options.
{
  config,
  lib,
  ...
}: let
  apps = config.omarchy.defaultApps;
in {
  config = lib.mkIf config.omarchy.enable {
    my.hyprland.settings = {
      calendar = {_var = apps.calendar;};
      reminders = {_var = apps.reminders;};
      terminal = {_var = apps.terminal;};
      editor = {_var = apps.editor;};
      fileManager = {_var = apps.fileManager;};
      browser = {_var = apps.browser;};
      music = {_var = apps.music;};
      passwordManager = {_var = apps.passwordManager;};
      messenger = {_var = apps.messenger;};
      webapp = {_var = apps.webapp;};
    };
  };
}
