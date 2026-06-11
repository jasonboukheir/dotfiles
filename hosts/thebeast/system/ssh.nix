# System-layer ssh client config + agent choice, replacing the old per-user
# home-manager ssh/_1password modules (issue #46). On thebeast the 1Password
# agent wins SSH_AUTH_SOCK: every host block also points IdentityAgent at it,
# and no ssh-agent-switcher runs here.
{lib, ...}: {
  programs.ssh.extraConfig = import ../../../modules/ssh/client-config.nix {
    inherit lib;
    identityAgent = "~/.1password/agent.sock";
  };

  # PAM-level (environment.sessionVariables maps $HOME to @{HOME}), so the
  # Hyprland session and login shells all inherit it.
  environment.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
}
