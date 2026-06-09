{...}: {
  environment = {
    shellInit = ''
      # /etc/profile brings in corp PATH entries (/etc/paths.d, /etc/profile.d),
      # but its `path_helper` call rebuilds PATH from /etc/paths{,.d} and demotes
      # the Nix profile dirs below /usr/local/bin, so corp tools (e.g.
      # /usr/local/bin/git) shadow Nix ones. Source it, then strip and re-prepend
      # the Nix dirs to restore their precedence.
      [[ -f /etc/profile ]] && . /etc/profile

      nixCleaned=":$PATH:"
      for nixBin in \
        "$HOME/.nix-profile/bin" \
        "/etc/profiles/per-user/$USER/bin" \
        "/run/current-system/sw/bin" \
        "/nix/var/nix/profiles/default/bin"; do
        nixCleaned="''${nixCleaned//:$nixBin:/:}"
      done
      nixCleaned="''${nixCleaned#:}"
      nixCleaned="''${nixCleaned%:}"
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$nixCleaned"
    '';
  };
}
