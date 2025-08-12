{...}: {
  programs.ssh = {
    enable = true;
    matchBlocks."*.od*" = {
      identityAgent = "~/.fb-sks-agent/ssh_auth_sock";
      identityFile = "~/.fb-sks-agent/jasonbk-cert.pub";
      forwardAgent = true;
    };
  };
}
