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
}
