{...}: {
  users.users.jasonbk.programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Jason Elie Bou Kheir";
        email = "5115126+jasonboukheir@users.noreply.github.com";
      };
      ui = {
        editor = "nvim";
        merge-editor = "nvim";
        pager = "less -FRX";
        default-command = "log";
      };
      git = {
        colocate = true;
        private-commits = "description(glob:'wip:*')";
      };
    };
  };
}
