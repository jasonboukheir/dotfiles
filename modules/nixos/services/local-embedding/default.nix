{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.local-embedding;

  stateDir = "/var/lib/local-embedding";

  serveArgs =
    [
      "serve"
      cfg.model
      "--served-model-name"
      cfg.alias
      "--runner"
      "pooling"
      "--dtype"
      cfg.dtype
      "--port"
      "8000"
      "--gpu-memory-utilization"
      (toString cfg.gpuMemoryUtilization)
      "--max-model-len"
      (toString cfg.maxModelLen)
      "--max-num-seqs"
      (toString cfg.maxNumSeqs)
    ]
    ++ lib.optionals cfg.enforceEager ["--enforce-eager"]
    ++ cfg.extraArgs;
in {
  options.services.local-embedding = {
    enable = lib.mkEnableOption "vLLM-XPU embedding server (Intel Arc, llm-scaler-vllm)";

    containerImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-llm-scaler-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-llm-scaler-vllm-image";
      description = ''
        OCI image used to run vLLM. Defaults to the same Intel
        llm-scaler-vllm image as the chat instance — running both off
        one image keeps the OneCCL / IPEX / level-zero stack identical.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host bind address for the published container port.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8001;
      description = ''
        Host-side port that the OpenAI-compatible `/v1/embeddings`
        endpoint is published on. Container-internal port is fixed to
        vLLM's default 8000.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      description = ''
        HuggingFace model id of the embedding model (positional arg of
        `vllm serve`). Pulled to `cacheDir` via HF_HOME on first start.
      '';
      example = "Qwen/Qwen3-Embedding-0.6B";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = "Served-model id over the OpenAI-compatible API (`--served-model-name`).";
      example = "qwen3-embedding-0.6b";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "float16";
      description = ''
        Data type for model weights. Matches the chat instance to
        avoid IPEX bf16/fp16 path divergence on the same card.
      '';
    };

    maxModelLen = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = ''
        Max tokens per embedding request. Caps the largest chunk a
        client may submit. Decoder-only embedders don't autoregress so
        the per-request memory cost is small; oversizing is cheap.
      '';
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.07;
      description = ''
        Fraction of XPU VRAM vLLM may use. Sized for a 0.6B-class
        pooling-mode embedder (no KV cache) on a 32 GiB B70:
        ~1.2 GiB FP16 weights + ~0.5 GiB profile-pass activations +
        ~0.2 GiB level-zero/IPEX overhead ≈ 1.9 GiB, fits 0.07×32 =
        2.24 GiB with a thin safety margin. Coexists with a chat vLLM
        at ~0.80 → 0.87 of the card committed, 13% reserved for the
        runtime. Bump in 0.01 increments if startup profiling OOMs.
      '';
    };

    maxNumSeqs = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = ''
        Cap on concurrent sequences in a single forward
        (`--max-num-seqs`). Bounds the activation footprint so the
        profile pass at startup doesn't overshoot
        `gpuMemoryUtilization`. vLLM's default (256) is sized for
        bulk batch encoding; for an interactive embedding service
        co-resident with a chat model 8 is plenty and keeps weights+
        activations comfortably inside the 2.24 GiB envelope.
      '';
    };

    enforceEager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass `--enforce-eager`. Same reason as the chat instance:
        Dynamo trips on IPEX's pybind11 C-extension on XPU. Eager-mode
        throughput is at the kernel ceiling for embedding workloads
        anyway.
      '';
    };

    cclEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        CCL_ZE_IPC_EXCHANGE = "sockets";
        CCL_PROCESS_LAUNCHER = "none";
        CCL_LOCAL_RANK = "0";
        CCL_LOCAL_SIZE = "1";
      };
      description = ''
        OneCCL env vars. Same single-card warmup workaround as
        services.local-llm.vllm — without these the all_reduce hangs
        even at world_size=1.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional flags appended to the `vllm serve` command line.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file with secrets (e.g. HF_TOKEN for gated repos).";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = stateDir;
      description = "Directory for the HuggingFace model cache (bind-mounted at `/cache`).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "local-embedding";
      description = "User account that owns `cacheDir`.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "local-embedding";
      description = "Group that owns `cacheDir`.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = {};
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.cacheDir;
      createHome = true;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    virtualisation.oci-containers.containers.local-embedding = {
      autoStart = true;
      image = "${cfg.containerImage.imageName}:${cfg.containerImage.imageTag}";
      imageFile = cfg.containerImage;

      environment =
        {HF_HOME = "/cache";}
        // cfg.cclEnv;

      volumes = [
        "${cfg.cacheDir}:/cache"
      ];

      ports = ["${cfg.host}:${toString cfg.port}:8000"];

      extraOptions = [
        "--device=/dev/dri"
        "--ipc=host"
      ];

      entrypoint = "/bin/bash";
      cmd = [
        "-lc"
        "cd /llm && exec vllm ${lib.escapeShellArgs serveArgs}"
      ];
    };

    systemd.services.podman-local-embedding = lib.mkIf (cfg.environmentFile != null) {
      serviceConfig.EnvironmentFile = cfg.environmentFile;
    };
  };
}
