{...}: {
  _1passwordSshHostGlob = "github.com";
  programs.ssh.settings."github.com".header = ''Match host "github.com" user git'';
}
