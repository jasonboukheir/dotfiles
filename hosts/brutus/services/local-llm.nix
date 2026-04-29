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
    backend = "vllm";
    port = lib.mkIf cfg.enable config.sunnycareboo.ports.values.local-llm;
    host = "127.0.0.1";

    llamacpp = {
      modelFile = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      modelUrl = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
      alias = "qwen3.6-35b-a3b-q4km";
      parallel = 1;
      contextSize = 131072;
    };

    # Validated 2026-04-29 against intel/llm-scaler-vllm:0.14.0-b8.2:
    # 19.01 GiB model, 103k-token KV cache headroom, ~20 tok/s
    # single-stream, 155 tok/s 8-way, 551 tok/s 32-way agg.
    # `Qwen/Qwen3.6-35B-A3B` is the BF16 base — sym_int4 wants the
    # un-quantized weights and packs to GGML Q4_0 in-place via IPEX.
    # Pre-quantized AWQ/GPTQ/compressed-tensors all hit
    # `gptq_marlin_repack` (CUDA-only) and crash; AutoRound's IPEX
    # path returns None for FusedMoE → BF16 OOM. See docs/VLLM.md.
    vllm = {
      model = "Qwen/Qwen3.6-35B-A3B";
      alias = "qwen3.6-35b-a3b";
      maxModelLen = 32768;
      # The Qwen3.6 chat template prefills `<think>\n` into the prompt,
      # so the model's output has `</think>` but no `<think>` opening
      # tag. The `qwen3` parser requires *both* tokens and falls back
      # to "all content" when start is missing — chain-of-thought leaks
      # into `content`. The `deepseek_r1` parser uses the same delimiters
      # but treats missing-start-token as "reasoning starts at offset 0",
      # which is exactly what this prefill pattern needs.
      reasoningParser = "deepseek_r1";
      limitMmPerPrompt = {
        image = 0;
        video = 0;
      };
    };
  };
}
