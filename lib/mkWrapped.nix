{
  lib,
  symlinkJoin,
  makeWrapper,
}: {
  pkg,
  name ? pkg.meta.mainProgram or pkg.pname,
  env ? {},
  flags ? [],
}:
symlinkJoin {
  name = "${name}-wrapped";
  paths = [pkg];
  nativeBuildInputs = [makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/${name} \
      ${lib.concatStringsSep " \\\n      " (
      lib.mapAttrsToList (k: v: "--set ${k} ${lib.escapeShellArg "${v}"}") env
      ++ map (f: "--add-flags ${lib.escapeShellArg f}") flags
    )}
  '';
  passthru = (pkg.passthru or {}) // {unwrapped = pkg;};
  meta = (pkg.meta or {}) // {mainProgram = name;};
}
