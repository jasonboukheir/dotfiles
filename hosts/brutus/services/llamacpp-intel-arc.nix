{pkgs-unstable, ...}: {
  services.llamacpp-intel-arc = {
    enable = true;

    modelFile = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    modelUrl = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    alias = "qwen3.6-35b-a3b-q4km";

    gpuRuntimeLibs = with pkgs-unstable; [level-zero intel-graphics-compiler];

    # Defaults from the module: port 8081 / 127.0.0.1, q4_0 KV,
    # Walsh-Hadamard rotation, Unsloth thinking-coding sampling
    # (temp 0.6 / top-p 0.95 / top-k 20), --parallel 2.
    # The binary itself comes from `pkgs.llamacpp-intel-arc-server`,
    # supplied by the llamacpp-intel-arc flake's overlay.
  };
}
