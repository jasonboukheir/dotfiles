final: _prev: {
  mkWrapped = {
    pkg,
    name ? pkg.meta.mainProgram or pkg.pname,
    env ? {},
    flags ? [],
    extraPaths ? [],
    # Extra packages merged into the join alongside pkg (e.g. to contribute
    # share/ files). pkg stays first so its passthru/meta (shellPath, …) win.
    extraMerge ? [],
  }:
    final.symlinkJoin {
      name = "${name}-wrapped";
      paths = [pkg] ++ extraMerge;
      nativeBuildInputs = [final.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/${name} \
          ${final.lib.concatStringsSep " \\\n      " (
          final.lib.mapAttrsToList (k: v: "--set ${k} ${final.lib.escapeShellArg "${v}"}") env
          ++ final.lib.optional (extraPaths != []) "--prefix PATH : ${final.lib.escapeShellArg (final.lib.makeBinPath extraPaths)}"
          ++ map (f: "--add-flags ${final.lib.escapeShellArg f}") flags
        )}
      '';
      passthru = (pkg.passthru or {}) // {unwrapped = pkg;};
      meta = (pkg.meta or {}) // {mainProgram = name;};
    };
}
