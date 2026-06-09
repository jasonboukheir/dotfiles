{...}: {
  users.users.jasonbk.programs.nushell = {
    enable = true;
    # vivid defaults to the `ansi` theme, so LS_COLORS follows the terminal's
    # ANSI palette (themed from base16 by stylix) rather than a pinned scheme.
    vivid.enable = true;
  };
}
