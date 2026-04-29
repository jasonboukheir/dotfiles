{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  sunnycareboo.ports.allocate.llamacpp = lib.mkIf config.services.llamacpp-intel-arc.enable 8081;
  services.llamacpp-intel-arc = {
    enable = true;
    port = config.sunnycareboo.ports.values.llamacpp;

    # Run inside intel/vllm:0.17.0-xpu so the oneAPI/level-zero/NEO/IGC
    # stack matches what the AICSS binary was AOT-compiled against.
    # Native execution against host nixpkgs Intel userspace was observed
    # at ~5 tok/s decode vs 28 tok/s in this container — same binary,
    # so the delta is the runtime stack, not the AICSS patches.
    enableContainer = true;

    modelFile = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    modelUrl = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    alias = "qwen3.6-35b-a3b-q4km";

    parallel = 1;
    contextSize = 131072;

    # gpuRuntimeLibs is unused in container mode but kept here so that
    # flipping back to native execution stays a one-line edit.
    gpuRuntimeLibs = with pkgs-unstable; [level-zero intel-graphics-compiler];

    # Defaults from the module: port 8081 / 127.0.0.1, q4_0 KV,
    # Walsh-Hadamard rotation, Unsloth thinking-coding sampling
    # (temp 0.6 / top-p 0.95 / top-k 20), --parallel 2.
    # The binary itself comes from `pkgs.llamacpp-intel-arc-server`,
    # supplied by the llamacpp-intel-arc flake's overlay.
  };
}
