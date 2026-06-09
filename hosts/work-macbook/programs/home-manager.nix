{...}: {
  home-manager.users.jasonbk.programs = {
    _1password.enable = true;
    ssh.enable = true;
    # ghostty stays on home-manager: it's a macOS GUI app (ghostty-bin + the
    # mac-app-util .app trampoline), and my.ghostty's baked --config-file wrapper
    # would only reach CLI launches, not the GUI app, so stylix theming wouldn't
    # apply. my.ghostty suits exec-launched ghostty (Linux), not darwin.
    ghostty.enable = true;
  };
}
