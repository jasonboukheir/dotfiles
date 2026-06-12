{
  config,
  lib,
  pkgs,
  ...
}: let
  displays = config.thebeast.displays;
  modeString = d: "${toString d.width}x${toString d.height}@${toString d.refreshHz}";
  gamer = config.gaming.user;
  gamerHome = config.users.users.${gamer}.home;

  # Schema per kwin's OutputConfigurationStore::load (kwin 6.6): a
  # top-level array that must contain both a "name":"outputs" and a
  # "name":"setups" section or the whole file is ignored. An empty
  # setups list is fine — generateConfig() still honors the per-output
  # state (mode, HDR) for outputs it can match by EDID; unmatched
  # displays get kwin's defaults.
  greeterOutputConfig = pkgs.writeText "sddm-kwinoutputconfig.json" (builtins.toJSON [
    {
      name = "outputs";
      data =
        map (d: {
          inherit (d) edidIdentifier edidHash;
          connectorName = lib.optionalString (d.connector != null) d.connector;
          mode = {
            inherit (d) width height;
            refreshRate = d.refreshMillihertz;
          };
          scale = 1;
          highDynamicRange = d.hdr;
          wideColorGamut = d.hdr;
          sdrBrightness = d.sdrPaperWhiteNits;
        })
        displays;
    }
    {
      name = "setups";
      data = [];
    }
  ]);

  # Gamescope's embedded DRM backend defaults to the highest-refresh
  # native mode, but jovian's gamescope-session exports
  # GAMESCOPE_MODE_SAVE_FILE and gamescope restores the per-panel mode
  # recorded there (the file Steam's display settings write through).
  # Keyed "<make> <model>" — per-display by construction.
  gamescopeModes = pkgs.writeText "gamescope-modes.cfg" (lib.concatMapStrings
    (d: "${d.make} ${d.model}:${modeString d}\n")
    displays);
in {
  config = lib.mkIf (displays != []) {
    # Hyprland: desc:-keyed rules so each profile follows the panel,
    # not the port. The omarchy fallback rule covers everything else.
    omarchy.extraMonitors =
      map (d: {
        output = "desc:${d.make} ${d.model}" + lib.optionalString (d.serial != "") " ${d.serial}";
        mode = modeString d;
        inherit (d) vrr hdr;
      })
      displays;

    # Both files get rewritten at runtime (kwin via storeConfig() on
    # every greeter start, Steam when display settings change), and
    # tmpfiles `C+` can NOT win the declarative copy back: despite the
    # popular "+ = overwrite" reading, systemd never replaces an
    # existing destination *file* — the + only lets a copy descend into
    # non-empty destination *directories* (tmpfiles.d(5), C/C+ entry).
    # So the copy landed exactly once, kwin's first rewrite (240Hz,
    # SDR, plus a "setups" entry that replays itself) stuck forever,
    # and the greeter drifted off the pinned mode. `L+` does
    # force-replace whatever is at the path with a store symlink on
    # every boot and activation. Both writers open the file in place
    # rather than rename-over (kwin: QFile::open(WriteOnly) in
    # OutputConfigurationStore::save), so runtime rewrites fail against
    # the read-only store and the pin holds for every greeter start —
    # deliberately: every consumer pinning the same stream is the whole
    # point of thebeast.displays.
    systemd.tmpfiles.rules = [
      # The greeter kwin runs as the sddm user (HOME=/var/lib/sddm) and
      # reads $XDG_CONFIG_HOME/kwinoutputconfig.json like any kwin.
      # Without it kwin picks the highest refresh at native resolution.
      "d /var/lib/sddm/.config 0750 sddm sddm -"
      "L+ /var/lib/sddm/.config/kwinoutputconfig.json - - - - ${greeterOutputConfig}"
      "d ${gamerHome}/.config 0755 ${gamer} ${gamer} -"
      "d ${gamerHome}/.config/gamescope 0755 ${gamer} ${gamer} -"
      "L+ ${gamerHome}/.config/gamescope/modes.cfg - - - - ${gamescopeModes}"
    ];
  };
}
