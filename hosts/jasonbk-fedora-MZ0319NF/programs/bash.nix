{...}: {
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      [ -f /etc/bashrc ] && . /etc/bashrc

      if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
        PATH="$HOME/.local/bin:$HOME/bin:$PATH"
      fi
      export PATH

      if [ -d ~/.bashrc.d ]; then
        for rc in ~/.bashrc.d/*; do
          [ -f "$rc" ] && . "$rc"
        done
        unset rc
      fi
    '';
    initExtra = ''
      if [[ -z "''${BASH_EXECED_FISH:-}" && $- == *i* ]] && command -v fish >/dev/null; then
        export BASH_EXECED_FISH=1
        exec fish
      fi
    '';
  };
}
