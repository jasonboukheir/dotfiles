{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vllm-xpu;
  chat = cfg.instances.chat;
  embedding = cfg.instances.embedding;
  stt = cfg.instances.stt;
  ports = config.homelab.ports.values;

  # Hash-pinned HF config.json fetch from PR #19's flake.lib helper.
  # `attnKernelSet = "auto"` unions the resulting `{ headDim; dtype; }`
  # entries to prune the FA2 Cartesian sweep down to the head_dim/dtype
  # combos these models actually dispatch to — drops ~600 TU compiles
  # to whatever the union covers (here: { 128, 256 } × { bf16 }).
  #
  # Bump by setting `rev` to a new HF commit and re-running:
  #   nix-prefetch-url "https://huggingface.co/$repo/resolve/$rev/config.json"
  #   nix hash convert --hash-algo sha256 --to sri <hash>
  hfFromConfig = inputs.vllm-xpu-nix.lib.${pkgs.stdenv.hostPlatform.system}.fromHfConfig;
  models = {
    chat = {
      repo = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
      rev = "d1fef185160f938fca00c3c664f21250dd544d63";
      hash = "sha256-zV62kIKjIDOWpQ6I6z0ll5n0+QIJEEMTrDP/rhml+1Y=";
    };
    embedding = {
      repo = "Qwen/Qwen3-Embedding-0.6B";
      rev = "97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3";
      hash = "sha256-tb8fUfxFvkc6VHGM75JEjZChvgAb+bmkS4x/EKGf6qk=";
    };
    # Whisper's config.json doesn't expose `head_dim` (vLLM derives it
    # from `d_model / num_attention_heads`), so the entry contributes
    # nulls to the FA2 union and prunes nothing — but the module still
    # requires a `modelMetadata.<repo>` entry for every enabled
    # instance under `attnKernelSet = "auto"`. The transcription path
    # uses `VLLM_ATTENTION_BACKEND = TRITON_ATTN` anyway.
    stt = {
      repo = "openai/whisper-large-v3-turbo";
      rev = "41f01f3fe87f28c78e2fbf8b568835947dd65ed9";
      hash = "sha256-xbUms+PNZM2JQNq7Rei6cmYp4i2O04nCm1UvkUDa8Eo=";
    };
  };
in {
  homelab.ports.allocate = {
    local-llm = lib.mkIf chat.enable 8000;
    local-embedding = lib.mkIf embedding.enable 8001;
    local-stt = lib.mkIf stt.enable 8002;
  };

  # intel-oneapi-base-toolkit is unfree; vllm-xpu's closure depends on
  # it. Scope the bypass instead of flipping allowUnfree on globally.
  allowUnfreePackageNames = [
    "intel-oneapi-base-toolkit"
  ];

  services.vllm-xpu = {
    # Track the jasonboukheir/vllm fork — carries the GDN graph-capture
    # fix (ccd77bdf4) and the GDN spec-decode FLA fallback (b6a544b82)
    # required for the kvCacheDtype + speculativeConfig combos below.
    # withTorchvision: Qwen3.6's qwen3_5 model module unconditionally
    # imports its qwen3_vl sibling, which pulls in transformers'
    # Qwen2VLImageProcessor → torchvision at registry-inspection time.
    # `--language-model-only` only mutes runtime per-prompt modality
    # caps; the import path runs before that flag takes effect.
    # https://github.com/jasonboukheir/vllm-xpu-nix/issues/37
    package = pkgs.vllm-xpu-unstable.withTorchvision true;

    attnKernelSet = "auto";

    modelMetadata =
      lib.mapAttrs' (
        _: m:
          lib.nameValuePair m.repo (hfFromConfig {inherit (m) repo rev hash;})
      )
      models;

    instances.chat = {
      enable = true;
      port = lib.mkIf chat.enable ports.local-llm;
      host = "127.0.0.1";

      model = models.chat.repo;
      servedName = "qwen3.6-35b-a3b";
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
      # 0.83 → ~26.6 GiB of the 32 GiB B70, leaving ~1.0 GiB headroom
      # after co-resident embedding (~2.24 GiB at 0.07 util) and
      # vLLM-served whisper-large-v3-turbo (~2.24 GiB at 0.07 util).
      # Dropped from 0.85 when STT moved off whisper.cpp (~0.7 GiB)
      # to vLLM (BF16 weights alone are ~1.6 GiB). The MTP head sits
      # inside this allocation and shrinks the KV pool;
      # turboquant_k3v4_nc keeps it large enough.
      gpuMemoryUtilization = 0.83;
      # Model-specific MTP dispatcher (vs generic "mtp" — same drafter,
      # model-aware plumbing). K=2 per Qwen's model-card sweet spot.
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
      # the cudagraph estimator on top of 0.85 util and starved the
      # KV pool. Updating K changes the round-up multiple.
      cudagraphCaptureSizes = [1 4];
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

    # Qwen3-Embedding-0.6B BF16: ~1.2 GiB on disk, served by vLLM-XPU
    # in pooling-only mode. 1024-dim output, last-token pooling
    # (vLLM auto-detects from the repo's pooling config). 8K context.
    # Co-resident on the B70 with the Qwen3.6-35B-A3B chat instance —
    # chat at gpuMemoryUtilization 0.85, this at 0.07.
    # Top of MTEB v2 in its size class as of 2026-04-29.
    instances.embedding = {
      enable = true;
      port = lib.mkIf embedding.enable ports.local-embedding;
      host = "127.0.0.1";

      runner = "pooling";
      model = models.embedding.repo;
      servedName = "qwen3-embedding-0.6b";
      maxModelLen = 8192;
      # vLLM's default (256) is sized for bulk batch encoding; for an
      # interactive embedding service co-resident with a chat model
      # 8 keeps activations comfortably inside the 2.24 GiB envelope.
      maxNumSeqs = 8;
      # ~1.2 GiB FP16 weights + ~0.5 GiB profile-pass activations +
      # ~0.2 GiB level-zero overhead ≈ 1.9 GiB, fits 0.07×32 =
      # 2.24 GiB with a thin safety margin. Bump in 0.01 increments
      # if startup profiling OOMs.
      gpuMemoryUtilization = 0.07;
      # Pooling-mode forward pass is at the kernel ceiling in eager;
      # graph capture would burn VRAM that the chat instance needs
      # for KV.
      enforceEager = true;
    };

    # whisper-large-v3-turbo BF16: ~1.6 GiB weights, 4 decoder layers
    # (vs 32 in v3) for ~6x faster decode at near-identical WER.
    # Multilingual. Replaces the whisper.cpp container — vLLM auto-
    # exposes /v1/audio/transcriptions when --task transcription is
    # set (PR jasonboukheir/vllm-xpu-nix#24). Co-resident on the B70
    # with the chat (0.83) and embedding (0.07) instances.
    instances.stt = {
      enable = true;
      port = lib.mkIf stt.enable ports.local-stt;
      host = "127.0.0.1";

      model = "openai/whisper-large-v3-turbo";
      servedName = "whisper-large-v3-turbo";
      dtype = "bfloat16";
      # Whisper's decoder is fixed at 448 output tokens by architecture.
      maxModelLen = 448;
      maxNumSeqs = 32;
      # Whisper implements SupportsTranscription via the audio modality;
      # the multimodal-budget init still needs an explicit per-prompt
      # cap or vLLM rejects the request shape.
      limitMmPerPrompt = {audio = 1;};
      kvCacheDtype = "fp8";
      # 0.07 → ~2.24 GiB. Weights (~1.6 GiB) + activations at bs=32 +
      # tiny KV pool (4 decoder layers × 448 ctx) fit with margin.
      # 0.05 (= 1.6 GiB) is below the weight footprint and OOMs at
      # load; 0.07 matches embedding's allocation.
      gpuMemoryUtilization = 0.07;
      # Whisper's encoder-decoder cross-attention path doesn't have
      # an XPU graph capture path yet; eager keeps init simple.
      enforceEager = true;
      # Default IPEX attention backend's Whisper coverage on XPU isn't
      # documented; TRITON_ATTN is the portable fallback the vLLM docs
      # recommend for transcription instances.
      # TODO: drop once IPEX attention covers Whisper cross-attn on XPU.
      # https://github.com/jasonboukheir/vllm-xpu-nix/issues/22
      attentionBackend = "TRITON_ATTN";
    };
  };

  # Shared HF cache (defaults to /var/cache/huggingface, group
  # `huggingface`) — services.vllm-xpu created the dir setgid +
  # group-writable. Add jasonbk to the group so dev shells can
  # write to the same content-addressed store the services pull
  # into, and point HF_HOME at it host-wide so `huggingface-cli`
  # / transformers / datasets land there by default.
  users.users.jasonbk.extraGroups =
    lib.optional (cfg.sharedHfCache != null) cfg.sharedHfCacheGroup;
  environment.sessionVariables = lib.mkIf (cfg.sharedHfCache != null) {
    HF_HOME = cfg.sharedHfCache;
  };
}
