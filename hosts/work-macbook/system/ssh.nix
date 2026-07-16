{lib, ...}: let
  lowboxSksAgentSocket = "/Users/jasonbk/.fb-sks-agent-lowbox/agent.sock";
  lowboxSksCertPublicKey = "/Users/jasonbk/.fb-sks-agent-lowbox/jasonbk-lowbox-cert.pub";
  lowboxSksPublicKey = "/Users/jasonbk/.ssh/lowbox_signing_key.pub";
in {
  # ssh_known_hosts is managed by Chef.
  environment.etc."ssh/ssh_known_hosts".enable = false;

  # Rendered into /etc/ssh/ssh_config.d/100-nix-darwin.conf (macOS's stock
  # ssh_config includes that directory). The lowbox SKS agent only serves
  # github.com; corp hosts keep the Chef-managed agent setup.
  programs.ssh.extraConfig =
    import ../../../modules/ssh/client-config.nix {
      inherit lib;
    }
    + ''

      Host github.com
        IdentityAgent "${lowboxSksAgentSocket}"
        IdentityFile ${lowboxSksCertPublicKey}
        IdentityFile ${lowboxSksPublicKey}
        IdentitiesOnly yes
        PreferredAuthentications publickey
        PubkeyAuthentication yes
    '';
}
