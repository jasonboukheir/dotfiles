{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vllm-xpu;
  chat = cfg.instances.chat;
  embedding = cfg.instances.embedding;
  stt = cfg.instances.stt;
  ports = config.homelab.ports.values;

  # Flip `selectedChatModel` to regression-test/compare a different chat model.
  # Each preset carries its HF identity and the name vLLM serves it under;
  # shared serving tuning lives in instances.chat below. Both are Qwen3.6 with
  # full-attention head_size=256, so they share the kernel buildout.
  chatModels = {
    qwen27b = {
      repo = "Lorbus/Qwen3.6-27B-int4-AutoRound";
      rev = "c3aea2d531678621989e5e2db034e32b22536e79";
      servedName = "qwen3.6-27b";
      quantization = "inc";
      dtype = "bfloat16";
      reasoningParser = "qwen3";
      toolCallParser = "qwen3_xml";
      # Mirrors the checkpoint's generation_config.json defaults.
      sampling = {
        temperature = 1.0;
        topP = 0.95;
        topK = 20;
      };
      speculative = {
        method = "mtp";
        num_speculative_tokens = 2;
      };
    };
    qwen35b = {
      repo = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
      rev = "d1fef185160f938fca00c3c664f21250dd544d63";
      servedName = "qwen3.6-35b-a3b";
      quantization = "gptq";
      dtype = "bfloat16";
      reasoningParser = "qwen3";
      toolCallParser = "qwen3_xml";
      sampling = {
        temperature = 1.0;
        topP = 0.95;
        topK = 20;
      };
      speculative = {
        method = "mtp";
        num_speculative_tokens = 2;
      };
    };
    # Uncensored/abliterated variant — BROKEN on this stack, kept for reference.
    # Community quants of the 35B-A3B all fail: AWQ checkpoints pack MoE experts
    # projection-first (vLLM qwen3_5 loader KeyError); this GPTQ repo loads but its
    # MTP head is mispacked (spec disabled below) AND it device-losts the XPU on the
    # first forward pass (UR_RESULT_ERROR_DEVICE_LOST). Plan: self-quant a bf16
    # abliterated base with AutoRound to get a clean, vLLM-compatible checkpoint.
    qwen35bHeretic = {
      repo = "llmfan46/Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-GPTQ-Int4";
      rev = "fb685a8409e4290f8a15dad0a691e6a9e3d42c3f";
      servedName = "qwen3.6-35b-a3b-heretic";
      quantization = "gptq";
      dtype = "bfloat16";
      reasoningParser = "qwen3";
      toolCallParser = "qwen3_xml";
      sampling = {
        temperature = 1.0;
        topP = 0.95;
        topK = 20;
      };
      # MTP head is mispacked in this checkpoint (vLLM KeyError loading the
      # drafter's fused experts); the main model loads fine, so disable spec.
      speculative = null;
    };
    # Gemma 4 26B-A4B (Google, 2026) — MoE, 26B total / 4B active, multimodal,
    # arch Gemma4ForConditionalGeneration. EXPERIMENTAL on this XPU stack;
    # untested here and quantized Gemma4 MoE is not yet working upstream (see
    # blockers below). Selectable for testing — leave selectedChatModel on a
    # Qwen preset for production.
    #
    # Quant: Intel's AutoRound uniform int4 (W4A16, sym gs128, auto_round:
    # auto_gptq packing). NOT the "-int4-mixed-" sibling: that one keeps
    # attn/mlp/router at int8, which the XPU INC path rejects at load
    # ("INC on XPU only supports 4-bit quantization, got weight_bits=8",
    # inc.py:416 apply_xpu_w4a16_quant_layer) -> deterministic crash-loop. This
    # uniform-4-bit checkpoint has no extra_config/int8 layers. No pure-GPTQ
    # quant exists; the cyankiwi compressed-tensors AWQ gs32 can't load on XPU
    # either (no awq_dequantize, vllm #41469).
    #
    # Status (2026-06-06): does NOT load yet — selecting this preset crash-loops
    # chat. Uniform-int4 cleared the INC weight_bits=8 crash, but loading then
    # dies: KeyError 'layers.0.moe.experts.0.down_proj.qweight'. ROOT CAUSE is
    # NOT the gemma4.py loader — it's inc.py: on XPU, INCConfig.get_quant_method
    # -> apply_xpu_w4a16_quant_layer returns a method only for LinearBase/
    # ParallelLMHead and `return None` for the FusedMoE experts, so w13/w2_qweight
    # params never register and the checkpoint's expert qweights have nowhere to
    # load. XPU INC W4A16 is linear-only; there is no XPU INC fused-MoE path.
    # The two "Gemma4 MoE loading" PRs (#42029, #43227) both edit gemma4.py and
    # do NOT touch inc.py, so neither fixes this. Reviving gemma4 here needs real
    # inc.py XPU MoE work (W4A16 fused-MoE), not a cherry-pick — and the adjacent
    # path is also broken (#43750: XPU WNA16 MoE wants CUDA-only gptq_marlin_repack).
    # Keep selectedChatModel on a Qwen preset.
    # bf16 Gemma4 MoE on XPU itself is already merged (xpu-kernels #251 head_dim
    # 512, #354 + vllm #42822 gelu_tanh MoE activation). If startup hits "kernel
    # not compiled", add the missing sliding-window head_size=256 attn variant
    # to withKernelConfig below.
    #
    # Reasoning: vLLM registers a "gemma4" reasoning parser (Gemma4 emits its CoT
    # inside <|channel>thought ... <channel|>; thinking is gated by
    # enable_thinking=True in the chat-template kwargs, default off). Sampling
    # values are Google/Unsloth's recommendation (temp 1.0, top_p 0.95, top_k 64),
    # which also match the checkpoint's generation_config.json.
    # Tool calling: no gemma4 tool-call parser exists upstream (only the separate
    # 270M `functiongemma` model has one), so toolCallParser is null — auto tool
    # choice is disabled for this preset. Revisit with `pythonic` if needed.
    #
    # MTP spec decode uses Google's SEPARATE drafter repo (not an in-model head
    # like Qwen). Merged in vllm v0.21.0 (#41745). To enable, set:
    #   speculative = {
    #     method = "mtp";
    #     model = "google/gemma-4-26B-A4B-it-assistant"; # rev 44033eb5
    #     num_speculative_tokens = 4;  # cudagraphCaptureSizes auto-follow -> [5 10]
    #   };
    # Disabled for now: Gemma4 MTP is broadly broken upstream (vllm #41789
    # ~0.2% accept, #42261 crashes, #41262 gibberish) and the BF16 drafter
    # mismatches this int4 target. Get the base model loading first.
    gemma4 = {
      repo = "Intel/gemma-4-26B-A4B-it-int4-AutoRound";
      rev = "edff62728a3c79ec541983b86a21674500e0f05b";
      servedName = "gemma-4-26b-a4b";
      # "inc" matches the qwen27b AutoRound preset: identical checkpoint metadata
      # (quant_method auto-round, packing auto_round:auto_gptq, gs128 sym), which
      # serves correctly on this stack with --quantization inc.
      quantization = "inc";
      dtype = "bfloat16";
      reasoningParser = "gemma4";
      toolCallParser = null;
      sampling = {
        temperature = 1.0;
        topP = 0.95;
        topK = 64;
      };
      speculative = null;
    };
  };
  selectedChatModel = "qwen35b";
  chatModel = chatModels.${selectedChatModel};

  # Verify pass processes 1 real + K spec tokens; vLLM rounds capture sizes up to
  # multiples of (K + 1), so capture (K+1) and 2*(K+1). K=0 when spec is off.
  specDecodingNum =
    if chatModel.speculative == null
    then 0
    else chatModel.speculative.num_speculative_tokens;
  chatCaptureSizes = [
    (1 + specDecodingNum)
    (2 * (1 + specDecodingNum))
  ];

  models = {
    embedding = {
      repo = "jinaai/jina-embeddings-v5-text-nano-retrieval";
      rev = "ac5d898c8d382b17167c33e5c8af644a3519b47d";
    };
    stt = {
      repo = "distil-whisper/distil-large-v3.5";
      rev = "728a7691f3ff1d3d971528d3203a6e9559165d41";
    };
  };
  vllm-enable = true;
in {
  homelab.ports.allocate = {
    local-llm = lib.mkIf chat.enable 8000;
    local-embedding = lib.mkIf embedding.enable 8001;
    local-stt = lib.mkIf stt.enable 8002;
  };

  allowUnfreePackageNames = [
    "intel-oneapi-base-toolkit"
  ];

  services.vllm-xpu = {
    # Partial kernel buildout (upstream vllm-xpu-kernels #324): compile only
    # the attn-kernel variants the served models dispatch to instead of the
    # full ~600-variant Cartesian sweep. The stock presets cover head 128
    # (Llama/Qwen), 192 (DeepSeek MLA), and 64 (gpt-oss); the *Extra lines add
    # Qwen3.6-27B's full-attention head_size=256 (num_attention_heads 24 /
    # num_key_value_heads 4 -> GQA 6 -> qgroup 8, no sliding window) on top,
    # without forking the preset. ~39 attn TUs vs 632 full.
    # If a model startup hits "kernel not compiled for this configuration",
    # add the missing variant line here or switch that stage to its *_full preset.
    package = (pkgs.vllm-xpu-unstable.withTorchvision true).withKernelConfig {
      chunkPrefill = "chunk_prefill_default";
      chunkPrefillExtra = [
        "256,true,true,false,false,false"
        "256,false,true,false,false,false"
        "256,false,true,false,false,true"
        # jina embedder: encoder, bidirectional (non-causal) head_size=64
        "64,false,false,false,false,false"
      ];
      pagedDecode = "paged_decode_default";
      pagedDecodeExtra = [
        "8,256,16,true,false,false"
        "8,256,32,true,false,false"
        "8,256,64,true,false,false"
        "8,256,64,false,false,false"
      ];
    };

    instances.chat = {
      enable = vllm-enable;
      port = lib.mkIf chat.enable ports.local-llm;
      host = "127.0.0.1";

      model = chatModel.repo;
      servedName = chatModel.servedName;
      dtype = chatModel.dtype;
      quantization = chatModel.quantization;
      # kvCacheDtype = "turboquant_k3v4_nc";
      kvCacheDtype = "fp8";
      maxModelLen = 131072;
      maxNumSeqs = 4;
      gpuMemoryUtilization = 0.85;
      speculativeConfig = chatModel.speculative;
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = chatCaptureSizes;
      reasoningParser = chatModel.reasoningParser;
      enableAutoToolChoice = chatModel.toolCallParser != null;
      toolCallParser = chatModel.toolCallParser;
      # No --temperature flag in vLLM serve; pin sampling defaults via the
      # model's generation config. Clients still override per-request.
      extraArgs = [
        "--override-generation-config"
        (builtins.toJSON {
          temperature = chatModel.sampling.temperature;
          top_p = chatModel.sampling.topP;
          top_k = chatModel.sampling.topK;
        })
      ];
      languageModelOnly = true;
    };

    instances.embedding = {
      enable = vllm-enable;
      port = lib.mkIf embedding.enable ports.local-embedding;
      host = "127.0.0.1";

      runner = "pooling";
      model = models.embedding.repo;
      servedName = "jina-embeddings-v5-nano";
      maxModelLen = 8192;
      maxNumSeqs = 8;
      gpuMemoryUtilization = 0.05;
      enforceEager = true;
      extraArgs = ["--trust-remote-code"];
    };

    instances.stt = {
      enable = false;
      port = lib.mkIf stt.enable ports.local-stt;
      host = "127.0.0.1";

      model = models.stt.repo;
      servedName = "distil-large-v3.5";
      dtype = "bfloat16";
      maxModelLen = 448;
      maxNumSeqs = 32;
      limitMmPerPrompt = {audio = 1;};
      kvCacheDtype = "fp8";
      gpuMemoryUtilization = 0.05;
      enforceEager = true;
      attentionBackend = "TRITON_ATTN";
    };
  };

  users.users.jasonbk.extraGroups =
    lib.optional (cfg.sharedHfCache != null) cfg.sharedHfCacheGroup;
  environment.sessionVariables = lib.mkIf (cfg.sharedHfCache != null) {
    HF_HOME = cfg.sharedHfCache;
  };
}
