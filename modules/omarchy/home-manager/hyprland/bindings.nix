{lib, ...}: let
  inline = lib.generators.mkLuaInline;
  escape = lib.escape ["\\" "\""];

  exec = cmd: inline ''hl.dsp.exec_cmd("${escape cmd}")'';
  execLocal = name: inline "hl.dsp.exec_cmd(${name})";
  dsp = expr: inline "hl.dsp.${expr}";

  bind = keys: dispatcher: {_args = [keys dispatcher];};
  bindFlags = keys: dispatcher: flags: {_args = [keys dispatcher flags];};

  appLauncherBinds = [
    (bind "ALT + C" (execLocal "calendar"))
    (bind "ALT + R" (execLocal "reminders"))
    (bind "ALT + return" (execLocal "terminal"))
    (bind "ALT + F" (execLocal "fileManager"))
    (bind "ALT + B" (execLocal "browser"))
    (bind "ALT + M" (execLocal "music"))
    (bind "ALT + Z" (execLocal "editor"))
    (bind "ALT + G" (execLocal "messenger"))
    (bind "ALT + slash" (execLocal "passwordManager"))
  ];

  workspaceBinds = builtins.concatMap (n: let
    ws = toString (
      if n == 0
      then 10
      else n
    );
    key = toString n;
  in [
    (bind "CTRL + ${key}" (dsp ''focus({ workspace = ${ws} })''))
    (bind "CTRL + SHIFT + ${key}" (dsp ''window.move({ workspace = ${ws} })''))
  ]) (builtins.genList (i: lib.mod (i + 1) 10) 10);
in {
  wayland.windowManager.hyprland.settings.bind =
    appLauncherBinds
    ++ workspaceBinds
    ++ [
      (bind "SUPER + space" (exec "wofi --show drun --sort-order=alphabetical"))
      (bind "CTRL + SHIFT + SPACE" (exec "pkill -SIGUSR1 waybar"))

      (bind "CTRL + Backspace" (dsp "window.close()"))

      (bind "CTRL + ESCAPE" (exec "hyprlock"))
      (bind "CTRL + SHIFT + ESCAPE" (exec "pkill -TERM steam; sleep 1; hyprexit"))
      (bind "CTRL + ALT + ESCAPE" (exec "reboot"))
      (bind "CTRL + SHIFT + ALT + ESCAPE" (exec "systemctl poweroff"))

      (bind "CTRL + J" (dsp ''layout("togglesplit")''))

      (bind "CTRL + left" (dsp ''focus({ direction = "left" })''))
      (bind "CTRL + right" (dsp ''focus({ direction = "right" })''))
      (bind "CTRL + up" (dsp ''focus({ direction = "up" })''))
      (bind "CTRL + down" (dsp ''focus({ direction = "down" })''))

      (bind "CTRL + comma" (dsp ''focus({ workspace = "-1" })''))
      (bind "CTRL + period" (dsp ''focus({ workspace = "+1" })''))

      (bind "CTRL + SHIFT + left" (dsp ''window.swap({ direction = "left" })''))
      (bind "CTRL + SHIFT + right" (dsp ''window.swap({ direction = "right" })''))
      (bind "CTRL + SHIFT + up" (dsp ''window.swap({ direction = "up" })''))
      (bind "CTRL + SHIFT + down" (dsp ''window.swap({ direction = "down" })''))

      (bind "CTRL + minus" (dsp ''window.resize({ x = -100, y = 0, relative = true })''))
      (bind "CTRL + equal" (dsp ''window.resize({ x = 100, y = 0, relative = true })''))
      (bind "CTRL + SHIFT + minus" (dsp ''window.resize({ x = 0, y = -100, relative = true })''))
      (bind "CTRL + SHIFT + equal" (dsp ''window.resize({ x = 0, y = 100, relative = true })''))

      (bind "CTRL + mouse_down" (dsp ''focus({ workspace = "e+1" })''))
      (bind "CTRL + mouse_up" (dsp ''focus({ workspace = "e-1" })''))

      (bind "CTRL + F1" (exec "~/.local/share/omarchy/bin/apple-display-brightness -5000"))
      (bind "CTRL + F2" (exec "~/.local/share/omarchy/bin/apple-display-brightness +5000"))
      (bind "SHIFT + CTRL + F2" (exec "~/.local/share/omarchy/bin/apple-display-brightness +60000"))

      (bind "CTRL + S" (dsp ''workspace.toggle_special("magic")''))
      (bind "CTRL + SHIFT + S" (dsp ''window.move({ workspace = "special:magic" })''))

      (bind "PRINT" (exec "hyprshot -m region"))
      (bind "SHIFT + PRINT" (exec "hyprshot -m window"))
      (bind "CTRL + PRINT" (exec "hyprshot -m output"))

      (bind "XF86Tools" (exec "gpu-screen-recorder-gtk"))

      (bind "ALT + PRINT" (exec "hyprpicker -a"))

      (bind "CTRL + ALT + V" (exec "ghostty --class clipse -e clipse"))

      # Mouse drag/resize (hyprlang bindm)
      (bindFlags "ALT + mouse:272" (dsp "window.drag()") {mouse = true;})
      (bindFlags "ALT + mouse:273" (dsp "window.resize()") {mouse = true;})

      # Audio + brightness, repeat-on-hold + works while locked (hyprlang bindel)
      (bindFlags "XF86AudioRaiseVolume" (exec "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+") {repeating = true; locked = true;})
      (bindFlags "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") {repeating = true; locked = true;})
      (bindFlags "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {repeating = true; locked = true;})
      (bindFlags "XF86AudioMicMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") {repeating = true; locked = true;})
      (bindFlags "XF86MonBrightnessUp" (exec "brightnessctl -e4 -n2 set 5%+") {repeating = true; locked = true;})
      (bindFlags "XF86MonBrightnessDown" (exec "brightnessctl -e4 -n2 set 5%-") {repeating = true; locked = true;})

      # Media keys, works while locked (hyprlang bindl)
      (bindFlags "XF86AudioNext" (exec "playerctl next") {locked = true;})
      (bindFlags "XF86AudioPause" (exec "playerctl play-pause") {locked = true;})
      (bindFlags "XF86AudioPlay" (exec "playerctl play-pause") {locked = true;})
      (bindFlags "XF86AudioPrev" (exec "playerctl previous") {locked = true;})
    ];
}
