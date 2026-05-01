{
  config,
  lib,
  pkgs,
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

    # Validated 2026-04-30 against vllm-xpu-int4-tq:fcc0c8365 with
    # palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4 + turboquant_k3v4_nc +
    # torch.compile + XPU graph capture: 20.15 GiB model, ~211k KV
    # tokens at 4k ctx, ~58 tok/s single-stream (~3x the legacy
    # 20 tok/s, matching llama.cpp Q4_K_M's hand-tuned SYCL).
    # KL vs FP16 KV at 4096 ctx / top-2000: 0.0179 with top-1 100%
    # / top-5 93% — k3v4 is functionally identical to FP16 for
    # greedy decoding.
    #
    # Replaces the older intel/llm-scaler-vllm:0.14.0-b8.2 +
    # sym_int4 path (19.01 GiB / 103k KV / 20 tok/s single).
    # The new path uses pre-quantized GPTQv2 sym int4 weights (no
    # IPEX online quantization, so torch.compile / Dynamo work),
    # routes the MoE through vllm-xpu-kernels' xpu_fused_moe(is_int4=True)
    # via INC, and compresses the K cache to 3-bit MSE-Lloyd-Max +
    # 4-bit V. Single-stream win comes from XPU graph replay
    # collapsing hundreds of per-kernel CPU dispatches into one per
    # token.
    vllm = {
      containerImage = pkgs.vllm-xpu-int4-tq-image;
      workingDir = "/workspace/vllm";
      model = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
      alias = "qwen3.6-35b-a3b";
      dtype = "bfloat16";
      quantization = "inc";
      kvCacheDtype = "turboquant_k3v4_nc";
      maxModelLen = 32768;
      # Single-stream perf opportunity: setting `enforceEager = false`
      # + `enableXpuGraph = true` + `cudagraphCaptureSizes = [1 2 4 8]`
      # would lift decode from ~20 tok/s to ~58 tok/s on dense models.
      # On Qwen3.6-A3B (hybrid: 10 full-attn + 30 GDN linear-attn
      # layers) the compiled path crashes the engine on real requests
      # with `RuntimeError: Expected core_attn_out.size(0) ==
      # num_actual_tokens to be true` from `torch.ops._xpu_C.gdn_attention`
      # (vllm/_xpu_ops.py:124). Profiling/warmup runs the GDN kernel
      # with dummy shapes that happen to match; chunked prefill in
      # production hits a different shape that trips the assertion.
      # Looks like a vllm-xpu-kernels GDN ↔ torch.compile interaction
      # bug. Reverting to eager keeps Qwen3.6 hybrid serving stable
      # at ~20 tok/s single-stream until that's fixed upstream.
      gpuMemoryUtilization = 0.80;
      enforceEager = true;
      # The Qwen3.6 chat template prefills the *prompt* differently
      # depending on `enable_thinking`: `<think>\n` for deep mode
      # (model emits `</think>` only), `<think>\n\n</think>\n\n` for
      # fast mode (model emits no tags). The bundled `qwen3` parser
      # in vLLM 0.20+ handles both: it reads `enable_thinking` from
      # chat_template_kwargs and the serving layer detects fast-mode
      # via `prompt_is_reasoning_end` to route deltas as content
      # without calling the streaming parser. Older vLLM (0.14) needed
      # a custom plugin (qwen3_aware_reasoning_parser.py) — no longer
      # needed.
      reasoningParser = "qwen3";
      limitMmPerPrompt = {
        image = 0;
        video = 0;
      };
    };
  };
}
