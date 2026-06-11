# nix-darwin's programs._1password ships the op CLI (and links it to
# /usr/local/bin/op for GUI integration). The GUI itself is the external
# /Applications app with its fixed agent socket path — manual, out of nix
# (issue #46).
{...}: {
  programs._1password.enable = true;
}
