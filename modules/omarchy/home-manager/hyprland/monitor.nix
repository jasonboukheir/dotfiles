{
  lib,
  osConfig,
  ...
}: let
  hdrCfg = osConfig.omarchy.hdr;
  brightness = toString hdrCfg.sdrBrightness;
  hdrArgs = lib.optionalString hdrCfg.enable ", bitdepth, 10, cm, hdr, sdrbrightness, ${brightness}";
in {
  wayland.windowManager.hyprland.settings.monitor = lib.mkDefault [
    ", preferred, auto, 1${hdrArgs}"
  ];
}
