{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    environment.systemPackages = with pkgs; [
      gpu-screen-recorder
      gpu-screen-recorder-gtk
      hyprshot
      hyprpicker
      hyprsunset
      brightnessctl
      pamixer
      playerctl
      pavucontrol
      libnotify
      nautilus
      clipse
      # `loginctl terminate-user` is the wrong primitive for "log out of
      # hyprland" under plasma-login-manager. The PLM helper that owns the
      # PAM session for the user lives *inside* the user's logind session
      # scope (Leader=plasmalogin-helper in `loginctl show-session`), so
      # terminate-user SIGTERMs it. PLM's Auth helper catches SIGTERM and
      # exits with code 1 (HELPER_AUTH_ERROR), and Display::slotHelperFinished
      # in plasma-login-manager 6.6 explicitly skips Display::stop() when
      # status == HELPER_AUTH_ERROR so that authentication failures don't
      # tear down the greeter. As a side effect, when the helper itself is
      # killed by SIGTERM the daemon never emits Display::stopped, Seat
      # never calls createDisplay(), and no new greeter ever appears —
      # exactly the "black framebuffer after hyprexit" we kept hitting.
      # Source:
      #   src/auth/Auth.cpp::childExited
      #   src/daemon/Display.cpp::slotHelperFinished
      #   src/helper/HelperApp.cpp SignalHandler wiring
      #
      # The correct primitive is to dispatch a clean shutdown to the
      # compositor and let its exit propagate through the wayland-session
      # process -> helper child-exit -> HELPER_SUCCESS -> Display::stop ->
      # Seat::displayStopped -> createDisplay. Hyprland's `dispatch exit`
      # already does this; the script then returns and the user-binding's
      # spawned shell exits, but the session leader (the helper, via its
      # exec'd wayland-session child) drives the actual teardown.
      #
      # Under the Lua config (see modules/my/programs/hyprland.nix),
      # `hyprctl dispatch <X>` lowers to `return hl.dispatch(<X>)` and Lua parses
      # the bare identifier `exit` as nil, so hl.dispatch rejects it
      # ("expected a dispatcher"). The Lua-mode spelling of the same
      # dispatcher is `hl.dsp.exit()`.
      # Refs: hyprwm/Hyprland#14255, hyprwm/Hyprland#14282.
      (writeShellScriptBin "hyprexit" ''
        exec ${hyprland}/bin/hyprctl dispatch 'hl.dsp.exit()'
      '')
      beeper
      supersonic-wayland
    ];
    allowUnfreePackageNames = ["beeper"];
  };
}
