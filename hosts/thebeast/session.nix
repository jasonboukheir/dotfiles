{...}: {
  imports = [./session];

  # plasma-login-manager (Plasma 6.6's experimental SDDM replacement)
  # ships without an Autologin.Relogin equivalent in its NixOS module,
  # so after jasonbk `hyprexit`s the autologin re-fires and gamer
  # bounces straight back into gamescope-wayland — observed as a blank
  # screen rather than a greeter. SDDM honours `autoLogin.relogin =
  # false` (forced in session/jovian-steam.nix), giving us the greeter
  # back on explicit logout. Re-evaluate once plasmalogin grows a
  # Relogin knob upstream.
  thebeast.displayManager = "sddm";

  gaming.enable = true;
  gaming.bigPicture.enable = true;
  gaming.roms.enable = true;
}
