{
  config,
  lib,
  ...
}: let
  hasBattery = config.omarchy.waybar.hasBattery;
in {
  config = lib.mkIf config.omarchy.enable {
    my.waybar = {
      enable = lib.mkDefault true;
      style = ''
        .modules-right > widget > * {
          padding: 0 8px;
        }
      '';
      settings = lib.mkDefault [
        {
          layer = "top";
          position = "top";
          spacing = 0;
          height = 26;
          modules-left = [
            "hyprland/workspaces"
          ];
          modules-center = [
            "clock"
          ];
          modules-right =
            [
              "tray"
              "bluetooth"
              "network"
              "wireplumber"
              "cpu"
              "power-profiles-daemon"
            ]
            ++ lib.optional hasBattery "battery";
          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            format-icons = {
              default = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
              active = "󱓻";
            };
            persistent-workspaces = {
              "1" = [];
              "2" = [];
              "3" = [];
              "4" = [];
              "5" = [];
            };
          };
          cpu = {
            interval = 5;
            format = "󰍛";
            on-click = "ghostty -e btop";
          };
          clock = {
            format = "{:%A %I:%M %p}";
            format-alt = "{:%d %B W%V %Y}";
            tooltip = false;
          };
          network = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format = "{icon}";
            format-wifi = "{icon}";
            format-ethernet = "󰀂";
            format-disconnected = "󰖪";
            tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
            tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
            tooltip-format-disconnected = "Disconnected";
            interval = 3;
            nospacing = 1;
            on-click = "ghostty -e nmtui";
          };
          battery = {
            interval = 5;
            format = "{capacity}% {icon}";
            format-discharging = "{icon}";
            format-charging = "{icon}";
            format-plugged = "";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            format-full = "Charged ";
            tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
            tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
            states = {
              warning = 20;
              critical = 10;
            };
          };
          bluetooth = {
            format = "󰂯";
            format-disabled = "󰂲";
            format-connected = "󰂯";
            tooltip-format = "Devices connected: {num_connections}";
            on-click = "blueman-manager";
          };
          wireplumber = {
            format = "";
            format-muted = "󰝟";
            scroll-step = 5;
            on-click = "pavucontrol";
            tooltip-format = "Playing at {volume}%";
            on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            max-volume = 150;
          };
          tray = {
            spacing = 13;
          };
          power-profiles-daemon = {
            format = "{icon}";
            tooltip-format = "Power profile: {profile}";
            tooltip = true;
            format-icons = {
              power-saver = "󰡳";
              balanced = "󰊚";
              performance = "󰡴";
            };
          };
        }
      ];
    };

    systemd.user.services.waybar = lib.mkIf config.my.waybar.enable {
      description = "Highly customizable Wayland bar for Sway and Wlroots based compositors.";
      documentation = ["https://github.com/Alexays/Waybar/wiki"];
      after = [config.omarchy.sessionTarget];
      partOf = [config.omarchy.sessionTarget];
      wantedBy = [config.omarchy.sessionTarget];
      serviceConfig = {
        ExecStart = lib.getExe config.my.waybar.finalPackage;
        ExecReload = "kill -SIGUSR2 $MAINPID";
        KillMode = "mixed";
        Restart = "on-failure";
      };
    };
  };
}
