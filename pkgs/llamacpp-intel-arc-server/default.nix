# Vendored patched llama-server (Intel SYCL, Battlemage Arc Pro B70).
#
# The binary is built outside Nix via
# `~/Projects/intellm/llamacpp-intel-arc/scripts/build-aicss.sh`
# (oneAPI / icpx isn't nix-packaged) and copied into bin/ here by
# `~/.config/nix/scripts/refresh-llamacpp-binary.sh`. Tracked in git
# via git-lfs — see .gitattributes at the repo root.
#
# Versioned per-build via the bin/ directory's narHash so each refresh
# produces a uniquely-named store path (visible in `nix store ls`).
#
# This is a bit-for-bit copy of the in-container build with its
# original RUNPATH (`/work/build/bin`) intact. Resolution at runtime
# goes through `setvars.sh` LD_LIBRARY_PATH inside the intel/vllm
# runtime image, where the matching oneAPI libraries already live.
{
  stdenv,
  lib,
}: let
  src = ./bin;
  buildStamp = builtins.substring 11 8 (builtins.hashFile "sha256" (src + "/llama-server"));
in
  stdenv.mkDerivation {
    pname = "llamacpp-intel-arc-server";
    version = "0.10.0-aicss-${buildStamp}";

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

      if [ ! -x "$src/llama-server" ]; then
        echo "ERROR: $src/llama-server not present in vendored bin/" >&2
        echo "       Refresh via:" >&2
        echo "         ~/.config/nix/scripts/refresh-llamacpp-binary.sh" >&2
        exit 1
      fi

      cp -L "$src/llama-server" "$out/bin/llama-server"

      for f in "$src"/lib*.so*; do
        [ -e "$f" ] || continue
        cp -L "$f" "$out/lib/"
      done

      runHook postInstall
    '';

    meta = with lib; {
      description = "Patched llama.cpp server (Intel SYCL, Battlemage)";
      longDescription = ''
        llama.cpp `llama-server` built from upstream master + 6
        cherry-picked Intel SYCL PRs + the IsoQuant rotation patch.
        Companion ggml/llama/mtmd `.so` files ship in `$out/lib`.
        Intended to be bind-mounted into the `intel/vllm:*-xpu`
        container so oneAPI / level-zero / NEO / IGC resolution goes
        through `setvars.sh` rather than the host's nixpkgs Intel
        userspace stack.
      '';
      homepage = "https://github.com/ggml-org/llama.cpp";
      license = licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "llama-server";
    };
  }
