{
  config,
  lib,
  ...
}: {
  # Stylix's HM qt target lays out ~/.config/Kvantum/Base16Kvantum as
  # a directory of per-file symlinks via xdg.configFile recursion. An
  # older home-manager generation linked the whole Base16Kvantum path
  # as a single symlink into its hm-files. That symlink breaks the
  # current generation's activation two ways:
  #   - Once the old generation is GC'd the symlink dangles, so
  #     linkGeneration's `mkdir -p ...Base16Kvantum` fails with
  #     "File exists" and the follow-up `ln -Tsf` errors with
  #     "No such file or directory" through the broken link.
  #   - While the old generation still exists the symlink resolves
  #     into the read-only store, so HM's backup step fails with
  #     `mv ...Base16Kvantum.kvconfig ...hm-backup: Read-only file
  #     system` and leaves the stale link in place pointing at the
  #     old theme.
  # Either way the path must become a real directory, so drop any
  # symlink there regardless of whether its target still exists.
  # Run before checkLinkTargets: stricter home-manager versions abort
  # there ("would be clobbered") before linkGeneration's backup step
  # ever runs, so this is the earliest point both failure modes share.
  home.activation.cleanStaleKvantumLink = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    stale="${config.home.homeDirectory}/.config/Kvantum/Base16Kvantum"
    if [ -L "$stale" ]; then
      run rm $VERBOSE_ARG -f "$stale"
    fi
  '';
}
