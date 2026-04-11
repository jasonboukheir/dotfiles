final: prev: {
  direnv = prev.direnv.overrideAttrs (previousAttrs: {
    # test-fish is flaky on darwin and gets SIGKILL'd during the build
    checkPhase = ''
      runHook preCheck

      make test-go test-bash test-zsh

      runHook postCheck
    '';
  });
}
