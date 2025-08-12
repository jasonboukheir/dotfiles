{...}: {
  programs.ssh {
    enable = true;
    matchBlocks."*.od*" = {
      # Use SKS agent for authentication
            IdentityAgent = "~/.fb-sks-agent/ssh_auth_sock";
            # Optional: Explicitly specify the SKS-issued certificate
            IdentityFile = "~/.fb-sks-agent/jasonbk-cert.pub";
            # Enable adding keys to the agent
            AddKeysToAgent = "yes";
    };
  };
}
