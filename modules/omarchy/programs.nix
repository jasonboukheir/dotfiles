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
    (lib.mkIf (cfg.enable && cfg.uwsm.enable) {
      # The hyprland package ships its own hyprland-uwsm.desktop session
      # (Exec=uwsm start -e -D Hyprland hyprland.desktop), so no
      # programs.uwsm.waylandCompositors registration is needed — adding
      # one would register the session name twice. withUWSM pulls in
      # programs.uwsm (the uwsm package, its user units, and dbus-broker).
      programs.hyprland.withUWSM = true;

      # The hyprland module registers its bare hyprland.desktop session
      # unconditionally, and the displayManager module has no exclusion
      # knob. Picking the bare entry would start Hyprland without uwsm —
      # sessionTarget never activates and the desktop comes up empty — so
      # hide it from greeters (NoDisplay) while keeping the file in place
      # for the providedSessions existence check.
      programs.hyprland.package = let
        hidden = pkgs.symlinkJoin {
          name = "hyprland-bare-session-hidden";
          paths = [pkgs.hyprland];
          postBuild = ''
            session=$out/share/wayland-sessions/hyprland.desktop
            real=$(readlink -f "$session")
            rm "$session"
            sed '/^\[Desktop Entry\]$/a NoDisplay=true' "$real" > "$session"
          '';
          passthru = {
            # version feeds the module's systemd.setPath version check.
            inherit (pkgs.hyprland) providedSessions version;
            # The module's package apply probes functionArgs of .override
            # (genFinalPackage) for an enableXWayland arg; a no-arg lambda
            # makes it leave the wrapper untouched — the underlying
            # hyprland already builds with XWayland.
            override = _args: hidden;
          };
          # Only mainProgram (for the security-wrapper's getExe); the full
          # meta carries outputsToInstall = ["out" "man"], outputs the
          # symlinkJoin doesn't have.
          meta = {inherit (pkgs.hyprland.meta) mainProgram;};
        };
      in
        hidden;
    })
  ];
}
