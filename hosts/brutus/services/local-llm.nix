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

    vllm = {
      containerImage = pkgs.vllm-xpu-int4-tq-image;
      workingDir = "/workspace/vllm";
      model = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
      alias = "qwen3.6-35b-a3b";
      dtype = "bfloat16";
      # INC dispatches the MoE through xpu_fused_moe(is_int4=True) for
      # the pre-quantized GPTQv2 weights — bypasses IPEX's online
      # quantization so torch.compile / Dynamo work on XPU.
      quantization = "inc";
      # 3-bit MSE-Lloyd-Max K + 4-bit V. KL vs FP16 KV at 4096 ctx is
      # 0.0179 with top-1 100% / top-5 93% — functionally identical
      # for greedy decoding.
      kvCacheDtype = "turboquant_k3v4_nc";
      maxModelLen = 65536;
      # Default 256 OOMs vLLM's startup memory-profile pass (worst-case
      # forward at max_num_seqs × max_num_batched_tokens) when the B70
      # is co-hosting Qwen3-Embedding-0.6B and whisper.cpp. 32 covers
      # single-stream + agentic sub-agent fan-out; beyond that, queue.
      maxNumSeqs = 32;
      # 0.85 → ~27.2 GiB of the 32 GiB B70, leaving ~1.9 GiB headroom
      # after co-resident embedding (~2.24 GiB at 0.07 util) and
      # whisper.cpp STT (~0.7 GiB). The MTP head sits inside this
      # allocation and shrinks the KV pool; turboquant_k3v4_nc keeps
      # it large enough. 0.93 over-commits when embedding+STT load.
      gpuMemoryUtilization = 0.85;
      # Model-specific MTP dispatcher (vs generic "mtp" — same drafter,
      # model-aware plumbing). Requires the spec-decode dispatcher
      # patch on XPU (vllm@b6a544b82, image tag spec-fix-b6a544b82):
      # the fused SYCL gdn_attention kernel has no spec-aware path,
      # so the dispatcher routes spec batches through the FLA Triton
      # flow that forward_cuda uses. K=2 per Qwen's model-card sweet
      # spot for this checkpoint.
      # speculativeConfig = {
      #   method = "qwen3_next_mtp";
      #   num_speculative_tokens = 2;
      # };
      enforceEager = false;
      enableXpuGraph = true;
      # Single-stream verify only. With MTP-K2, vLLM rounds capture
      # sizes up to multiples of (num_speculative_tokens + 1) = 3
      # (`adjust_cudagraph_sizes_for_spec_decode`), so size 3 covers
      # 1 real + 2 spec tokens; multi-stream verify falls back to
      # eager. Adding size 12 (4-way concurrent verify) over-reserved
      # the cudagraph estimator on top of 0.85 util and starved the KV
      # pool. Updating K changes the round-up multiple (e.g. K=3 → [4]).
      # Requires the GDN-input-slicing fix (image tag gdn-fix-ccd77bdf4)
      # — without it the SYCL GDN kernel asserts
      # `core_attn_out.size(0) == num_actual_tokens` whenever captured
      # size > real batch.
      cudagraphCaptureSizes = [1, 4];
      # Custom variant of bundled `qwen3`. Two differences in the
      # source:
      #   (1) Adds an enable_thinking=False short-circuit inside
      #       extract_reasoning_streaming. The bundled parser instead
      #       relies on the serving layer's prompt_is_reasoning_end
      #       check against the prompt's </think> token id; this
      #       parser is defensive against chat-template tokenization
      #       where </think> doesn't render as the single reserved id.
      #   (2) Drops the bundled parser's implicit-reasoning-end logic
      #       for unclosed <tool_call> inside thinking — a Qwen3.5
      #       quirk not exhibited by this Qwen3.6 checkpoint.
      # Pairs with the litellm overlay patch — without it LiteLLM
      # drops deep-mode delta.reasoning chunks before they reach OWUI.
      reasoningParser = "qwen3";
      # Independent of the reasoning parser: thinking splits on
      # </think> first, then tool-call extraction runs on the
      # post-think content. Agentic flows: prefer the qwen3.6-fast
      # LiteLLM variant — tool-using turns skip the think pass.
      enableAutoToolChoice = true;
      toolCallParser = "qwen3_coder";
      # Text-only inference on a VL-tagged checkpoint. Sets every
      # modality's per-prompt limit to 0 (config/multimodal.py:315).
      # Vision-tower weights still load if present in the checkpoint;
      # this only changes the runtime limit.
      languageModelOnly = true;
    };
  };
}
