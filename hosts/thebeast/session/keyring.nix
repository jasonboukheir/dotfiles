{...}: {
  # KDE's ksecretd (the kwallet -> org.freedesktop.secrets bridge) maps every
  # Secret Service collection onto a separate kwallet and drives a GUI
  # wallet-creation wizard to make one. In jasonbk's windowless Hyprland
  # session that wizard can't render ("Using kwallet without parent window!",
  # "QWizard::field: No such field 'key'"), so the `default` collection alias
  # never persists and libsecret clients (Brave, GNOME Calendar) spawn a fresh
  # throwaway "Default Keyring_N" on every launch and never store secrets.
  #
  # gnome-keyring is the supported Secret Service for non-Plasma sessions:
  # pam_gnome_keyring unlocks the login keyring with the login password at
  # greeter login and claims org.freedesktop.secrets before any client asks,
  # so ksecretd is never activated. The login pam stack covers the greeter
  # and gamer's autologin under either DM: both sddm and plasmalogin
  # substack/include login (sddm-autologin includes sddm, which includes
  # login).
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
