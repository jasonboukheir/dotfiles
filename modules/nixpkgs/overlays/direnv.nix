final: prev: {
  direnv = prev.direnv.overrideAttrs (previousAttrs: {
    # TODO: drop this checkPhase override once the Nix Mach-O codesigning fix
    # lands. test-fish gets SIGKILL'd during the build on darwin, likely the
    # same root cause as the fish overlay.
    # https://github.com/NixOS/nix/pull/15638
    checkPhase = ''
      runHook preCheck

      make test-go test-bash test-zsh

      runHook postCheck
    '';
  });
}
