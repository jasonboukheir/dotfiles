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
    };
    qwen35b = {
      repo = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
      rev = "d1fef185160f938fca00c3c664f21250dd544d63";
      servedName = "qwen3.6-35b-a3b";
      quantization = "gptq";
    };
  };
  selectedChatModel = "qwen35b";
  chatModel = chatModels.${selectedChatModel};

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
      dtype = "bfloat16";
      quantization = chatModel.quantization;
      # kvCacheDtype = "turboquant_k3v4_nc";
      kvCacheDtype = "fp8";
      maxModelLen = 131072;
      maxNumSeqs = 4;
      gpuMemoryUtilization = 0.85;
      speculativeConfig = {
        method = "mtp";
        num_speculative_tokens = 2;
      };
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = [3 6];
      reasoningParser = "qwen3";
      enableAutoToolChoice = true;
      toolCallParser = "qwen3_xml";
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
