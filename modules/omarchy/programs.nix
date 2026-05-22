{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.hyprland.enable = lib.mkDefault config.omarchy.enable;

  # Strip the upstream `hyprland-uwsm.desktop` session entry out of
  # what the hyprland package contributes to wayland-sessions/, so
  # SDDM's dropdown doesn't list the uwsm-managed variant alongside
  # plain Hyprland. We keep systemd integration intact (withSystemd
  # stays true) — the only effect is the missing session file and
  # the updated providedSessions list. symlinkJoin keeps the original
  # store path cached and just rewrites the directory layout, so we
  # don't pay a Hyprland rebuild.
  programs.hyprland.package = lib.mkIf config.omarchy.enable (
    let
      # Pull in the man output too so the joined result is a single
      # store path with both `bin/Hyprland` and `share/man/`. Upstream
      # hyprland's meta.outputsToInstall is `[ "out" "man" ]`; if we
      # leave that on the symlinkJoin output, environment.systemPackages
      # tries to install a non-existent `man` output and aborts.
      filtered = pkgs.symlinkJoin {
        name = "hyprland-${pkgs.hyprland.version}-no-uwsm";
        paths = [pkgs.hyprland pkgs.hyprland.man];
        postBuild = ''
          rm -f $out/share/wayland-sessions/hyprland-uwsm.desktop
        '';
        passthru =
          pkgs.hyprland.passthru
          // {
            providedSessions = ["hyprland"];
          };
        meta =
          pkgs.hyprland.meta
          // {
            outputsToInstall = ["out"];
          };
        # The hyprland NixOS module reads cfg.package.{version,pname}
        # directly (e.g. systemd.setPath.enable's default branches on
        # lib.versionOlder version "0.41.2"). symlinkJoin doesn't
        # surface these on its own, so pass them through.
        inherit (pkgs.hyprland) version pname;
      };
    in
      # programs.hyprland.package.apply wraps with genFinalPackage,
      # which probes pkg.override.__functionArgs to decide whether to
      # re-invoke it. symlinkJoin's result has no .override, so attach
      # a stub: any arg set yields the same filtered package.
      filtered // {override = _: filtered;}
  );
}
