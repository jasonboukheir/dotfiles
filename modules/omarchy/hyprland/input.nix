{
  config,
  lib,
  ...
}: {
  config = lib.mkIf config.omarchy.enable {
    # https://wiki.hypr.land/Configuring/Variables/#input
    # mkDefault on the `input` key only: the HM original wrapped the whole
    # `settings.config` set, which lost the per-key priority merge against
    # the plain `settings.config` definitions (envs/looknfeel) and silently
    # dropped this section from the rendered config.
    my.hyprland.settings.config.input = lib.mkDefault {
      kb_layout = "us";
      # kb_variant =
      # kb_model =
      kb_options = "compose:caps";
      # kb_rules =

      follow_mouse = 1;

      sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

      touchpad = {
        natural_scroll = false;
      };
    };

    # https://wiki.hypr.land/Configuring/Variables/#gestures
    # my.hyprland.settings.config.gestures = {
    #   workspace_swipe = false;
    # };
  };
}
