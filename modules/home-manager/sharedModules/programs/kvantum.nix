{
  config,
  lib,
  ...
}: {
  # Stylix's HM qt target lays out ~/.config/Kvantum/Base16Kvantum as
  # a directory of per-file symlinks via xdg.configFile recursion. An
  # older home-manager generation linked the whole Base16Kvantum path
  # as a single symlink into its hm-files; once that generation is
  # GC'd the symlink dangles. linkGeneration then does
  #   mkdir -p ~/.config/Kvantum/Base16Kvantum
  # which fails with "File exists" (the dangling symlink), and the
  # follow-up `ln -Tsf` errors out with "No such file or directory"
  # because the parent path resolves through the broken link. Drop
  # the stale symlink ahead of linkGeneration so HM can recreate the
  # directory cleanly.
  home.activation.cleanStaleKvantumLink = lib.hm.dag.entryBefore ["linkGeneration"] ''
    stale="${config.home.homeDirectory}/.config/Kvantum/Base16Kvantum"
    if [ -L "$stale" ] && [ ! -e "$stale" ]; then
      run rm $VERBOSE_ARG -f "$stale"
    fi
  '';
}
