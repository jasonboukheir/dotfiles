{
  lib,
  osConfig,
  ...
}: let
  hdrCfg = osConfig.omarchy.hdr;
  monCfg = osConfig.omarchy.monitor;

  baseSettings = {
    output = "";
    mode = monCfg.mode;
    position = monCfg.position;
    scale = monCfg.scale;
    vrr = monCfg.vrr;
  };

  hdrSettings = lib.optionalAttrs hdrCfg.enable {
    bitdepth = 10;
    cm = hdrCfg.colorManagement;
    sdrbrightness = hdrCfg.sdrBrightness;
    sdrsaturation = hdrCfg.sdrSaturation;
    sdr_min_luminance = hdrCfg.sdrMinLuminance;
    sdr_max_luminance = hdrCfg.sdrMaxLuminance;
  };
in {
  wayland.windowManager.hyprland.settings.monitorv2 = [
    (baseSettings // hdrSettings)
  ];
}
