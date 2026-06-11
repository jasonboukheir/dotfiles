# nix-darwin's programs._1password ships the op CLI (and links it to
# /usr/local/bin/op for GUI integration). The GUI itself is the external
# /Applications app with its fixed agent socket path — manual, out of nix
# (issue #46). The 1Password agent wins SSH_AUTH_SOCK on this host.
{...}: {
  programs._1password.enable = true;

  environment.variables.SSH_AUTH_SOCK = "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
}
