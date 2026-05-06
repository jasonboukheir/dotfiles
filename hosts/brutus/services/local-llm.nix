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

    # Validated 2026-05-06 against vllm-xpu-int4-tq:spec-fix-b6a544b82
    # with palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4 + turboquant_k3v4_nc +
    # torch.compile + XPU graph capture at [1, 4]: 20.15 GiB model,
    # ~65 tok/s single-stream, ~218 tok/s 4-way agg. KL vs FP16 KV at
    # 4096 ctx / top-2000: 0.0179 with top-1 100% / top-5 93% — k3v4 is
    # functionally identical to FP16 for greedy decoding.
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
      # Caps the engine at 32 concurrent sequences. vLLM's startup
      # memory-profile pass shapes a worst-case forward at
      # max_num_seqs × max_num_batched_tokens to size activation peak;
      # leaving max_num_seqs at the default 256 OOMs init when the B70
      # is also hosting the Qwen3-Embedding-0.6B and whisper.cpp
      # models. 32 covers single-stream + agentic sub-agent fan-out
      # without inflating the profile peak; beyond that requests queue.
      maxNumSeqs = 32;
      # XPU graph capture at verify-pass token counts 4 and 16. With
      # MTP-K3 enabled, vLLM rounds every capture size up to a multiple
      # of (num_speculative_tokens + 1) = 4
      # (`adjust_cudagraph_sizes_for_spec_decode`,
      # vllm/config/compilation.py:1447), so listing 1 silently
      # collapses to 4 anyway — the value of the list is in the larger
      # shapes. Size 4 covers MTP-K3 single-stream verify (1 real + 3
      # spec = 4 tokens through the target). Size 16 covers 4-way
      # concurrent verify (4 seqs × 4 tokens) — the agentic
      # tool-fanout case. Beyond 4 concurrent active spec decodes, the
      # verify pass falls back to eager. Required the GDN-input-slicing
      # fix in image tag gdn-fix-ccd77bdf4 — without it, the SYCL GDN
      # kernel asserts `core_attn_out.size(0) == num_actual_tokens`
      # whenever the captured size > real batch. Updating K (=2 or =5)
      # changes the round-up multiple and requires re-picking these
      # numbers (e.g. K=2 → [3, 12]).
      #
      # 0.85 hands vLLM ~27.2 GiB on the 32 GiB B70, leaving ~1.9 GiB
      # headroom after the co-resident embedding (~2.24 GiB at 0.07
      # util) and whisper.cpp STT (~0.7 GiB). The MTP-K3 head
      # (+1.57 GiB) sits inside vLLM's allocation and shrinks the KV
      # pool — with turboquant_k3v4_nc the pool stays large enough for
      # typical sessions. Going higher (0.93 from the original MTP
      # checklist) over-commits when embedding+STT are loaded.
      gpuMemoryUtilization = 0.85;
      # MTP-K3: 1.13–1.49x speedup vs no-spec baseline on B70 with
      # the spec-decode dispatcher patch (vllm@b6a544b82, image tag
      # spec-fix-b6a544b82). Per-position acceptance 85.6% / 71.0% /
      # 58.6% on Qwen3.6-A3B (canonical MTP shape). The fused SYCL
      # gdn_attention kernel has no spec-aware path; the dispatcher
      # detects spec batches and routes them through the same FLA
      # Triton flow that forward_cuda uses (non-spec batches keep the
      # SYCL fast path).
      speculativeConfig = {
        method = "mtp";
        num_speculative_tokens = 3;
      };
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = [4 16];
      # The Qwen3.6 chat template prefills `<think>\n` for deep mode
      # (verified via /tokenize: prompt ends with `<|im_start|>assistant
      # \n<think>\n`) and `<think>\n\n</think>\n\n` for fast mode. The
      # model emits `</think>` + answer inline in deep mode, and just
      # the answer in fast mode — never an opening `<think>` tag in
      # its output. So OWUI's inline tag splitter has nothing to anchor
      # on for deep mode, and we need a server-side parser.
      #
      # vLLM 0.20.1rc1's bundled `qwen3` parser is supposed to short-
      # circuit fast mode via the serving layer's `prompt_is_reasoning
      # _end` check (prompt already contains `</think>`). Empirically
      # the short-circuit doesn't fire for this Qwen3.6 build, so fast
      # mode tokens all stream on `delta.reasoning` instead of
      # `delta.content` — every fast-mode chat renders as one giant
      # "Thinking…" block in OWUI with no answer text.
      #
      # The custom `qwen3_aware` plugin reads
      # `chat_template_kwargs.enable_thinking` at parser-init time and
      # bypasses extraction entirely in fast mode (returns
      # `DeltaMessage(content=delta_text)` directly). Deep mode falls
      # through to normal `<think>...</think>` splitting.
      #
      # Pairs with the litellm overlay patch — without that patch,
      # LiteLLM drops the deep-mode `delta.reasoning` chunks before
      # they reach OWUI.
      reasoningParser = "qwen3_aware";
      reasoningParserPlugin = ../../../modules/nixos/services/local-llm/qwen3_aware_reasoning_parser.py;
      limitMmPerPrompt = {
        image = 0;
        video = 0;
      };
    };
  };
}
