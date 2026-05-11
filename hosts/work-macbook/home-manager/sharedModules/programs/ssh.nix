{...}: {
  _1passwordSshHostGlob = "github.com";
  programs.ssh.matchBlocks."github.com".match = ''host "github.com" user git'';
}
