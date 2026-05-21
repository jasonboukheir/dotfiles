{lib, ...}: {
  options.omarchy.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Apply omarchy desktop modules (Hyprland stack, waybar, mako, …)
      to this Home Manager user. The system-level `omarchy.enable`
      controls whether these HM modules get loaded at all; this
      per-user toggle lets individual users opt out — used by thebeast's
      gamer account so the Plasma session doesn't start
      hyprpolkitagent et al.
    '';
  };
}
