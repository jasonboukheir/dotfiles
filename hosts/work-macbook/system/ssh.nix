{lib, ...}: {
  # ssh_known_hosts is managed by Chef.
  environment.etc."ssh/ssh_known_hosts".enable = false;

  # Rendered into /etc/ssh/ssh_config.d/100-nix-darwin.conf (macOS's stock
  # ssh_config includes that directory). The 1Password agent only serves
  # github.com as the git user; corp hosts keep the Chef-managed agent setup.
  programs.ssh.extraConfig = import ../../../modules/ssh/client-config.nix {
    inherit lib;
    identityAgent = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    identityAgentMatch = ''Match host "github.com" user git'';
  };
}
