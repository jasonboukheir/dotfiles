{...}: {
  users.users.jasonbk.programs.gh = {
    enable = true;
    # TODO: replace the "nvim" literal with users.users.jasonbk.editor
    # https://github.com/jasonboukheir/dotfiles/issues/62
    settings.editor = "nvim";
  };
}
