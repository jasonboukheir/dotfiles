{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  hdrCfg = osConfig.omarchy.hdr;
  brightness = toString hdrCfg.sdrBrightness;
  hdrArgs = lib.optionalString hdrCfg.enable ", bitdepth, 10, cm, hdr, sdrbrightness, ${brightness}";

  sdr-brightness = pkgs.writeShellApplication {
    name = "sdr-brightness";
    runtimeInputs = [pkgs.gawk];
    text = ''
      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/sdr-brightness"
      STEP=0.1
      MIN=0.5
      MAX=2.5
      DEFAULT=${brightness}

      get_brightness() {
        if [ -f "$STATE_FILE" ]; then
          cat "$STATE_FILE"
        else
          echo "$DEFAULT"
        fi
      }

      apply() {
        local val="$1"
        val=$(awk -v v="$val" -v mn="$MIN" -v mx="$MAX" 'BEGIN { if (v<mn) v=mn; if (v>mx) v=mx; printf "%.1f", v }')
        echo "$val" > "$STATE_FILE"
        hyprctl keyword monitor ", preferred, auto, 1, bitdepth, 10, cm, hdr, sdrbrightness, $val" > /dev/null 2>&1
      }

      case "''${1:-get}" in
        get) get_brightness ;;
        waybar)
          printf '{"tooltip": "SDR Brightness: %s"}\n' "$(get_brightness)"
          ;;
        up)
          current=$(get_brightness)
          apply "$(awk -v c="$current" -v s="$STEP" 'BEGIN { printf "%.1f", c+s }')"
          ;;
        down)
          current=$(get_brightness)
          apply "$(awk -v c="$current" -v s="$STEP" 'BEGIN { printf "%.1f", c-s }')"
          ;;
        reset) apply "$DEFAULT" ;;
        *) echo "Usage: sdr-brightness {get|up|down|reset|waybar}"; exit 1 ;;
      esac
    '';
  };
in {
  wayland.windowManager.hyprland.settings.monitor = lib.mkDefault [
    ", preferred, auto, 1${hdrArgs}"
  ];

  home.packages = lib.mkIf hdrCfg.enable [sdr-brightness];
}
