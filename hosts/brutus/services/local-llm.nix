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
      # Compile + XPU graph capture costs ~5.4 GiB on top of the model:
      # 1.4 GiB for the captured Level Zero command lists themselves
      # (with cudagraphCaptureSizes = [1 2 4 8]) plus ~4 GiB of
      # profiling/Inductor workspace. vLLM probes peak memory at
      # max-num-seqs × max-num-batched-tokens to size that workspace,
      # so capping max-num-seqs is what keeps it bounded — at the
      # default it balloons and OOMs the KV budget at 32k ctx.
      #
      # Bumping gpu-mem-util 0.80 → 0.85 (embedding at 0.07 keeps
      # total at 0.92, ~2.5 GiB headroom) and capping max-num-seqs at
      # 8 (matches the largest captured graph size) makes everything
      # fit and lifts single-stream from ~20 tok/s to ~58 tok/s
      # — matching llama.cpp Q4_K_M's hand-tuned SYCL pipeline. See
      # vllm-intel-arc/results/PERF-INVESTIGATION.md for the full
      # bandwidth analysis and CPU-dispatch diagnosis.
      gpuMemoryUtilization = 0.85;
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = [1 2 4 8];
      extraArgs = ["--max-num-seqs" "8"];
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
