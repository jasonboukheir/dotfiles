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

  models = {
    chat = {
      repo = "Lorbus/Qwen3.6-27B-int4-AutoRound";
      rev = "c3aea2d531678621989e5e2db034e32b22536e79";
      hash = "sha256-zV62kIKjIDOWpQ6I6z0ll5n0+QIJEEMTrDP/rhml+1Y=";
    };
    embedding = {
      repo = "Qwen/Qwen3-Embedding-0.6B";
      rev = "97b0c614be4d77ee51c0cef4e5f07c00f9eb65b3";
      hash = "sha256-tb8fUfxFvkc6VHGM75JEjZChvgAb+bmkS4x/EKGf6qk=";
    };
    stt = {
      repo = "openai/whisper-large-v3-turbo";
      rev = "41f01f3fe87f28c78e2fbf8b568835947dd65ed9";
      hash = "sha256-xbUms+PNZM2JQNq7Rei6cmYp4i2O04nCm1UvkUDa8Eo=";
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
    package = pkgs.vllm-xpu-unstable.withTorchvision true;

    instances.chat = {
      enable = vllm-enable;
      port = lib.mkIf chat.enable ports.local-llm;
      host = "127.0.0.1";

      model = models.chat.repo;
      servedName = "qwen3.6-27b";
      dtype = "bfloat16";
      quantization = "inc";
      kvCacheDtype = "turboquant_k3v4_nc";
      maxModelLen = 131072;
      maxNumSeqs = 3;
      gpuMemoryUtilization = 0.75;
      speculativeConfig = {
        method = "mtp";
        num_speculative_tokens = 2;
      };
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = null;
      # Force PIECEWISE-only — the default FULL_AND_PIECEWISE trips
      # `sycl_ext_oneapi_work_group_scratch_memory feature is not yet
      # available for use with the SYCL Graph extension` inside
      # _vllm_fa2_C.varlen_fwd during FULL decode capture
      # (vllm_xpu_kernels FA2 + oneAPI 2025.3 SYCL Graph).
      extraArgs = [
        "--compilation-config"
        (builtins.toJSON {
          cudagraph_mode = "PIECEWISE";
          cudagraph_capture_sizes = [ 3 9 ];
        })
      ];
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
      servedName = "qwen3-embedding-0.6b";
      maxModelLen = 8192;
      maxNumSeqs = 8;
      gpuMemoryUtilization = 0.07;
      enforceEager = true;
    };

    instances.stt = {
      enable = vllm-enable;
      port = lib.mkIf stt.enable ports.local-stt;
      host = "127.0.0.1";

      model = "openai/whisper-large-v3-turbo";
      servedName = "whisper-large-v3-turbo";
      dtype = "bfloat16";
      maxModelLen = 448;
      maxNumSeqs = 32;
      limitMmPerPrompt = {audio = 1;};
      kvCacheDtype = "fp8";
      gpuMemoryUtilization = 0.07;
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
