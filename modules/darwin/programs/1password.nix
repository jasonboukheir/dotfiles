{ ... }:
{
  home-manager.users.jasonbk = {
    programs._1password.enable = true;
    programs.git.enable = true;
    programs.ssh.enable = true;
  };
}
