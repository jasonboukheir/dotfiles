{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-llm;
in {
  homelab.ports.allocate.local-llm = lib.mkIf cfg.enable 8000;

  services.local-llm = {
    enable = true;
    backend = "vllm";
    port = lib.mkIf cfg.enable config.homelab.ports.values.local-llm;
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
      # Co-resident with services.local-embedding (Qwen3-Embedding-0.6B
      # at 0.10) on the same B70. 0.80 + 0.10 = 0.90 of 32 GiB,
      # leaving ~10% for level-zero / IPEX runtime overhead.
      gpuMemoryUtilization = 0.80;
      # The Qwen3.6 chat template prefills the *prompt* differently
      # depending on `enable_thinking`: `<think>\n` for deep mode (model
      # emits `</think>` only), `<think>\n\n</think>\n\n` for fast mode
      # (model emits no tags). The bundled parsers can't handle both —
      # `qwen3` demands both tokens in the output and leaks deep-mode
      # CoT into `content`; `deepseek_r1` treats fast-mode output (no
      # `</think>`) as "still inside reasoning" and dumps every token
      # into `reasoning_content`. The custom plugin reads the per-request
      # `chat_template_kwargs.enable_thinking` and switches between the
      # two extraction strategies at parser-init time.
      reasoningParser = "qwen3_aware";
      reasoningParserPlugin = ../../../modules/nixos/services/local-llm/qwen3_aware_reasoning_parser.py;
      limitMmPerPrompt = {
        image = 0;
        video = 0;
      };
    };
  };
}
