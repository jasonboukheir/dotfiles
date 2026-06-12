{config, ...}: let
  preselectSession = "${config.thebeast.greeterDefaultSession}.desktop";
in {
  # Jovian sets services.displayManager.defaultSession = "gamescope-wayland",
  # which NixOS' sddm module folds into a computed default for
  # General.DefaultSession and then merges *under* sddm.settings via
  # recursiveUpdate. Writing settings.General.DefaultSession directly wins
  # without needing an override priority. The greeter only appears after an
  # explicit logout (see relogin=false in session/jovian-steam.nix), and at
  # that point the only user looking at it is jasonbk.
  services.displayManager.sddm.settings.General.DefaultSession = preselectSession;

  # The greeter compositor must be kwin, not the sddm module's weston
  # default. weston 15.0 aborts during backend init on this host's
  # amdgpu pair (RX 9070 XT dGPU + Raphael iGPU):
  #   weston: drm-formats.c:451: weston_drm_format_add_modifier:
  #   Assertion `!weston_drm_format_has_modifier(format, modifier)' failed
  # so every session exit (including Steam's Switch to Desktop, which
  # lands on the greeter via relogin=false) left a dead VT instead of a
  # greeter. kwin was the de-facto compositor while plasma6 was enabled
  # (the plasma6 module sets it); dropping plasma silently flipped this
  # back to weston. Pin the known-good choice.
  # TODO: drop if weston's duplicate-modifier assert is fixed upstream —
  # https://gitlab.freedesktop.org/wayland/weston/-/issues
  services.displayManager.sddm.wayland.compositor = "kwin";
}
