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

  # Per-user session allowlist for the SDDM greeter. The dropdown
  # filters to these entries when the matching account is selected;
  # the underlying session files stay installed so autoLogin and
  # `steamosctl set-default-desktop-session` keep resolving. plasmax11
  # is intentionally absent from both lists — nobody on this host
  # uses the X11 variant.
  thebeast.sessionsByUser = {
    jasonbk = ["hyprland"];
    gamer = ["plasma" "gamescope-wayland"];
  };

  gaming.enable = true;
  gaming.bigPicture.enable = true;
  gaming.roms.enable = true;
}
