final: _prev: {
  mkWrapped = {
    pkg,
    name ? pkg.meta.mainProgram or pkg.pname,
    env ? {},
    flags ? [],
    # Shell snippets run by the wrapper before exec'ing pkg (makeWrapper
    # --run), e.g. to seed mutable runtime state the program owns afterwards.
    run ? [],
    extraPaths ? [],
    # Extra packages merged into the join alongside pkg (e.g. to contribute
    # share/ files). pkg stays first so its passthru/meta (shellPath, …) win.
    extraMerge ? [],
    # Extra passthru attrs on the wrapped package (e.g. the baked config file,
    # so out-of-wrapper consumers like darwin's Dock-path seeding reuse it).
    passthru ? {},
  }: let
    # Outputs an env would have installed alongside pkg (man, terminfo, …).
    # The wrapper is single-output, so fold their content into the join and
    # claim only `out` in meta below — otherwise buildenv chases the copied
    # meta.outputsToInstall into outputs the wrapper doesn't have.
    installedExtraOutputs =
      final.lib.remove (pkg.outputName or "out")
      (pkg.meta.outputsToInstall or []);
  in
    final.symlinkJoin {
      name = "${name}-wrapped";
      paths = [pkg] ++ map (o: pkg.${o}) installedExtraOutputs ++ extraMerge;
      nativeBuildInputs = [final.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${name} \
          ${final.lib.concatStringsSep " \\\n      " (
          final.lib.mapAttrsToList (k: v: "--set ${k} ${final.lib.escapeShellArg "${v}"}") env
          ++ final.lib.optional (extraPaths != []) "--prefix PATH : ${final.lib.escapeShellArg (final.lib.makeBinPath extraPaths)}"
          ++ map (r: "--run ${final.lib.escapeShellArg r}") run
          ++ map (f: "--add-flags ${final.lib.escapeShellArg f}") flags
        )}
      '';
      passthru = (pkg.passthru or {}) // passthru // {unwrapped = pkg;};
      meta =
        (pkg.meta or {})
        // {
          mainProgram = name;
          outputsToInstall = ["out"];
        };
    };
}
