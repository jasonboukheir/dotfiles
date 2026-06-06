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

  chatModels = {
    qwen27b = {
      repo = "Lorbus/Qwen3.6-27B-int4-AutoRound";
      rev = "c3aea2d531678621989e5e2db034e32b22536e79";
      servedName = "qwen3.6-27b";
      quantization = "inc";
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
      # MTP head is mispacked in this checkpoint
      speculative = null;
    };
    # MTP spec decode uses Google's SEPARATE drafter repo (not an in-model head
    # like Qwen). Merged in vllm v0.21.0 (#41745). To enable, set:
    #   speculative = {
    #     method = "mtp";
    #     model = "google/gemma-4-26B-A4B-it-assistant"; # rev 44033eb5
    #     num_speculative_tokens = 4;  # cudagraphCaptureSizes auto-follow -> [5 10]
    #   };
    gemma4 = {
      repo = "Intel/gemma-4-26B-A4B-it-int4-AutoRound";
      rev = "edff62728a3c79ec541983b86a21674500e0f05b";
      servedName = "gemma-4-26b-a4b";
      quantization = "gptq";
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
