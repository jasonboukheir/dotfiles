# Vendored whisper-server (Intel SYCL, Battlemage Arc Pro B70).
#
# The binary is built outside Nix via
# `~/Projects/intellm/whispercpp-intel-arc/scripts/build-aicss.sh`
# (oneAPI / icpx isn't nix-packaged) and copied into bin/ here by
# `~/.config/nix/scripts/refresh-whispercpp-binary.sh`. Tracked in git
# via git-lfs — see .gitattributes at the repo root.
#
# Mirrors `pkgs/llamacpp-intel-arc-server/` — bit-for-bit copy of the
# in-container build with original RUNPATH (`/work/build/bin`) intact.
# Resolution at runtime goes through `setvars.sh` LD_LIBRARY_PATH inside
# the intel/vllm runtime image, where the matching oneAPI libraries live.
{
  stdenv,
  lib,
}: let
  src = ./bin;
  buildStamp = builtins.substring 11 8 (builtins.hashFile "sha256" (src + "/whisper-server"));
in
  stdenv.mkDerivation {
    pname = "whispercpp-intel-arc-server";
    version = "mainline-${buildStamp}";

    inherit src;

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontPatchELF = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib

      if [ ! -x "$src/whisper-server" ]; then
        echo "ERROR: $src/whisper-server not present in vendored bin/" >&2
        echo "       Build via:" >&2
        echo "         (cd ~/Projects/intellm/whispercpp-intel-arc && scripts/build-aicss.sh)" >&2
        echo "       Then refresh via:" >&2
        echo "         ~/.config/nix/scripts/refresh-whispercpp-binary.sh" >&2
        exit 1
      fi

      cp -L "$src/whisper-server" "$out/bin/whisper-server"

      for f in "$src"/lib*.so*; do
        [ -e "$f" ] || continue
        cp -L "$f" "$out/lib/"
      done

      runHook postInstall
    '';

    meta = with lib; {
      description = "whisper.cpp `whisper-server` (Intel SYCL, Battlemage)";
      longDescription = ''
        whisper.cpp `whisper-server` built from upstream master with the
        SYCL backend enabled (`GGML_SYCL=ON`). Companion ggml `.so`
        files ship in `$out/lib`. Intended to be bind-mounted into the
        `intel/vllm:*-xpu` container so oneAPI / level-zero / NEO / IGC
        resolution goes through `setvars.sh` rather than the host's
        nixpkgs Intel userspace stack.
      '';
      homepage = "https://github.com/ggml-org/whisper.cpp";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "whisper-server";
    };
  }
