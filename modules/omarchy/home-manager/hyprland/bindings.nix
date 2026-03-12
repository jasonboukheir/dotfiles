{...}: let
  appLauncherBindings = [
    "ALT, C, exec, $calendar"
    "ALT, R, exec, $reminders"
    "ALT, return, exec, $terminal"
    "ALT, F, exec, $fileManager"
    "ALT, B, exec, $browser"
    "ALT, M, exec, $music"
    "ALT, Z, exec, $editor"
    "ALT, G, exec, $messenger"
    "ALT, slash, exec, $passwordManager"
  ];

  workspaceBindings = builtins.concatMap (n: [
    "CTRL, ${toString n}, workspace, ${toString (if n == 0 then 10 else n)}"
    "CTRL SHIFT, ${toString n}, movetoworkspace, ${toString (if n == 0 then 10 else n)}"
  ]) (builtins.genList (i: let n = (i + 1) mod 10; in n) 10);
in {
  wayland.windowManager.hyprland.settings = {
    bind =
      appLauncherBindings
      ++ workspaceBindings
      ++ [
        "SUPER, space, exec, wofi --show drun --sort-order=alphabetical"
        "CTRL SHIFT, SPACE, exec, pkill -SIGUSR1 waybar"

        "CTRL, Backspace, killactive,"

        "CTRL, ESCAPE, exec, hyprlock"
        "CTRL SHIFT, ESCAPE, exec, pkill -TERM steam; sleep 1; hyprexit"
        "CTRL ALT, ESCAPE, exec, reboot"
        "CTRL SHIFT ALT, ESCAPE, exec, systemctl poweroff"

        "CTRL, J, togglesplit,"

        "CTRL, left, movefocus, l"
        "CTRL, right, movefocus, r"
        "CTRL, up, movefocus, u"
        "CTRL, down, movefocus, d"

        "CTRL, comma, workspace, -1"
        "CTRL, period, workspace, +1"

        "CTRL SHIFT, left, swapwindow, l"
        "CTRL SHIFT, right, swapwindow, r"
        "CTRL SHIFT, up, swapwindow, u"
        "CTRL SHIFT, down, swapwindow, d"

        "CTRL, minus, resizeactive, -100 0"
        "CTRL, equal, resizeactive, 100 0"
        "CTRL SHIFT, minus, resizeactive, 0 -100"
        "CTRL SHIFT, equal, resizeactive, 0 100"

        "CTRL, mouse_down, workspace, e+1"
        "CTRL, mouse_up, workspace, e-1"

        "CTRL, F1, exec, ~/.local/share/omarchy/bin/apple-display-brightness -5000"
        "CTRL, F2, exec, ~/.local/share/omarchy/bin/apple-display-brightness +5000"
        "SHIFT CTRL, F2, exec, ~/.local/share/omarchy/bin/apple-display-brightness +60000"

        "CTRL, S, togglespecialworkspace, magic"
        "CTRL SHIFT, S, movetoworkspace, special:magic"

        ", PRINT, exec, hyprshot -m region"
        "SHIFT, PRINT, exec, hyprshot -m window"
        "CTRL, PRINT, exec, hyprshot -m output"

        "ALT, PRINT, exec, hyprpicker -a"

        "CTRL ALT, V, exec, ghostty --class clipse -e clipse"
      ];

    bindm = [
      "ALT, mouse:272, movewindow"
      "ALT, mouse:273, resizewindow"
    ];

    bindel = [
      ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
      ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
    ];

    bindl = [
      ", XF86AudioNext, exec, playerctl next"
      ", XF86AudioPause, exec, playerctl play-pause"
      ", XF86AudioPlay, exec, playerctl play-pause"
      ", XF86AudioPrev, exec, playerctl previous"
    ];
  };
}
