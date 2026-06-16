{
  config,
  lib,
  pkgs,
  ...
}: let
  inline = lib.generators.mkLuaInline;

  hdrCfg = config.omarchy.hdr;
  monCfg = config.omarchy.monitor;
  headlessCfg = config.omarchy.headlessFallback;

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

  # A virtual output with no DRM connector, so it neither retrains the
  # DisplayPort link nor disturbs thebeast's single-stream handoff; it just
  # keeps the monitor count above zero when the physical panel drops out.
  headlessRule = {
    output = headlessCfg.name;
    inherit (headlessCfg) mode position;
    scale = 1;
    vrr = 0;
    hdr = false;
  };
in {
  config = lib.mkIf config.omarchy.enable (lib.mkMerge [
    {
      my.hyprland.settings.monitor =
        map mkRule ([fallbackRule] ++ config.omarchy.extraMonitors);
    }
    (lib.mkIf headlessCfg.enable {
      # Named rules resolve before the empty-output fallback, so this pins the
      # dummy's mode/position regardless of list order.
      my.hyprland.settings.monitor = [(mkRule headlessRule)];
      # exec-once equivalent: the physical output already exists at
      # hyprland.start, so the create call lands and the output persists.
      my.hyprland.settings.on = [
        {
          _args = [
            "hyprland.start"
            (inline ''function() hl.exec_cmd("hyprctl output create headless") end'')
          ];
        }
      ];

      # Build-time reminder to drop the workaround once the deployed Hyprland
      # carries the fix. Probe pkgs.hyprland (the package omarchy wraps), not
      # config.programs.hyprland.package — the latter is built from
      # my.hyprland.settings, which this branch defines, so gating it on its own
      # version would be infinite recursion. A warnings entry keeps the version
      # probe in a lazy value the module fixpoint never forces structurally.
      warnings = lib.optional (lib.versionAtLeast pkgs.hyprland.version "0.56")
        "omarchy.headlessFallback is on but Hyprland ${pkgs.hyprland.version} carries the empty-monitor fix (hyprwm/Hyprland 0aa7a84); drop the workaround.";
    })
  ]);
}
