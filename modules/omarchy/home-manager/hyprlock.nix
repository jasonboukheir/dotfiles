{...}: {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 2;
        no_fade_in = false;
      };
    };
  };
}
