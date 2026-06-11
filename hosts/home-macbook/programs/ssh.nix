# Rendered into /etc/ssh/ssh_config.d/100-nix-darwin.conf (macOS's stock
# ssh_config includes that directory), replacing the old per-user
# home-manager ssh module (issue #46).
{lib, ...}: {
  programs.ssh.extraConfig = import ../../../modules/ssh/client-config.nix {
    inherit lib;
    identityAgent = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
}
