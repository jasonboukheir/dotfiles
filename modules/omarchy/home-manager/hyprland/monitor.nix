{
  lib,
  osConfig,
  ...
}: let
  hdrCfg = osConfig.omarchy.hdr;
  brightness = toString hdrCfg.sdrBrightness;
  saturation = toString hdrCfg.sdrSaturation;
  hdrArgs = lib.optionalString hdrCfg.enable
    ", bitdepth, 10, cm, hdr, sdrbrightness, ${brightness}, sdrsaturation, ${saturation}";
in {
  wayland.windowManager.hyprland.settings.monitor = lib.mkDefault [
    ", preferred, auto, 1${hdrArgs}"
  ];
}
