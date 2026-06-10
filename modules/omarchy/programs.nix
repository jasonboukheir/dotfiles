{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omarchy;
in {
  config = lib.mkMerge [
    {programs.hyprland.enable = lib.mkDefault cfg.enable;}
    (lib.mkIf cfg.enable {
      # The my.hyprland wrapper carries the generated hyprland.lua in its
      # session entry's Exec (see modules/my/programs/hyprland.nix); making
      # it the module package routes the greeter session, the uwsm entry's
      # `uwsm start … hyprland.desktop` resolution, and the PATH-installed
      # binaries through it.
      programs.hyprland.package = let
        wrapped = config.my.hyprland.finalPackage;

        # The hyprland module registers its bare hyprland.desktop session
        # unconditionally, and the displayManager module has no exclusion
        # knob. Under uwsm, picking the bare entry would start Hyprland
        # without uwsm — sessionTarget never activates and the desktop
        # comes up empty — so hide it from greeters (NoDisplay) while
        # keeping the file in place for the providedSessions existence
        # check (and for the uwsm entry's resolution — config args
        # included).
        hidden = pkgs.symlinkJoin {
          name = "hyprland-bare-session-hidden";
          paths = [wrapped];
          postBuild = ''
            session=$out/share/wayland-sessions/hyprland.desktop
            real=$(readlink -f "$session")
            rm "$session"
            sed '/^\[Desktop Entry\]$/a NoDisplay=true' "$real" > "$session"
          '';
          passthru = {
            # version feeds the module's systemd.setPath version check.
            inherit (wrapped) providedSessions version;
            # The module's package apply probes functionArgs of .override
            # (genFinalPackage) for an enableXWayland arg; a no-arg lambda
            # makes it leave the wrapper untouched — the underlying
            # hyprland already builds with XWayland.
            override = _args: hidden;
          };
          # Only mainProgram (for the security-wrapper's getExe); the full
          # meta carries outputsToInstall = ["out" "man"], outputs the
          # symlinkJoin doesn't have.
          meta = {inherit (wrapped.meta) mainProgram;};
        };
      in
        if cfg.uwsm.enable
        then hidden
        else wrapped;
    })
    (lib.mkIf (cfg.enable && cfg.uwsm.enable) {
      # The hyprland package ships its own hyprland-uwsm.desktop session
      # (Exec=uwsm start -e -D Hyprland hyprland.desktop), so no
      # programs.uwsm.waylandCompositors registration is needed — adding
      # one would register the session name twice. withUWSM pulls in
      # programs.uwsm (the uwsm package, its user units, and dbus-broker).
      programs.hyprland.withUWSM = true;
    })
  ];
}
