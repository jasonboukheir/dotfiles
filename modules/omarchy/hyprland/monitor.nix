{
  config,
  lib,
  ...
}: let
  hdrCfg = config.omarchy.hdr;
  monCfg = config.omarchy.monitor;

  hdrSettings = lib.optionalAttrs hdrCfg.enable ({
      bitdepth = 10;
      cm = hdrCfg.colorManagement;
      sdrbrightness = hdrCfg.sdrBrightness;
      sdrsaturation = hdrCfg.sdrSaturation;
      sdr_min_luminance = hdrCfg.sdrMinLuminance;
      sdr_max_luminance = hdrCfg.sdrMaxLuminance;
    }
    // lib.optionalAttrs (hdrCfg.minLuminance != null) {min_luminance = hdrCfg.minLuminance;}
    // lib.optionalAttrs (hdrCfg.maxLuminance != null) {max_luminance = hdrCfg.maxLuminance;}
    // lib.optionalAttrs (hdrCfg.maxAvgLuminance != null) {max_avg_luminance = hdrCfg.maxAvgLuminance;});

  mkRule = entry:
    {
      inherit (entry) output mode position scale vrr;
    }
    // lib.optionalAttrs entry.hdr hdrSettings;

  fallbackRule = {
    output = "";
    inherit (monCfg) mode position scale vrr hdr;
  };
in {
  config = lib.mkIf config.omarchy.enable {
    my.hyprland.settings.monitor =
      map mkRule ([fallbackRule] ++ config.omarchy.extraMonitors);
  };
}
