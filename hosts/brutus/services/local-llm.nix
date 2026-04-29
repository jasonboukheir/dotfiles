{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-llm;
in {
  sunnycareboo.ports.allocate.local-llm = lib.mkIf cfg.enable 8000;

  services.local-llm = {
    enable = true;
    # vLLM-XPU on B70 Pro is mid kernel-migration as of 2026-04-29 —
    # AutoRound/INC paths disabled in newer images, MoE INT4 kernels
    # not landed, FusedMoE unpacks to BF16 → OOM on 32 GB. Sticking with
    # llama.cpp until upstream MoE INT4 ships (vLLM-Omni 2026 H1 roadmap:
    # https://github.com/vllm-project/vllm-omni/issues/2570). The vllm
    # config below stays so the switch is one line when kernels land.
    backend = "llamacpp";
    port = config.sunnycareboo.ports.values.local-llm;
    host = "127.0.0.1";

    llamacpp = {
      modelFile = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      modelUrl = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      alias = "qwen3.6-35b-a3b-q4km";
      parallel = 1;
      contextSize = 131072;
    };

    vllm = {
      # 4-bit quant of Qwen3.6-35B-A3B (MoE, 3B active). Despite the repo
      # name saying "AWQ", cyankiwi's build is actually llmcompressor's
      # compressed-tensors pack-quantized format — vLLM consumes it via
      # `--quantization compressed-tensors`. ~19 GB on disk.
      #
      # Unsloth only ships GGUF for 3.6
      # (https://github.com/unslothai/unsloth/issues/4761).
      # QuantTrio's true-AWQ build is bigger (~27 GB) because it leaves
      # self_attn / shared_expert / linear_attn unquantized.
      model = "cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit";
      alias = "qwen3.6-35b-a3b-awq";
      maxModelLen = 32768;
      extraArgs = [
        "--quantization"
        "compressed-tensors"
        "--gpu-memory-utilization"
        "0.9"
        "--reasoning-parser"
        "qwen3"
      ];
    };
  };
}
