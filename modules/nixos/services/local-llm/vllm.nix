{
  config,
  lib,
  pkgs,
  ...
}: let
  topCfg = config.services.local-llm;
  cfg = topCfg.vllm;
in {
  options.services.local-llm.vllm = {
    containerImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-llm-scaler-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-llm-scaler-vllm-image";
      description = ''
        OCI image derivation for the vLLM container. Defaults to
        Intel's Battlematrix-targeted llm-scaler-vllm fork — the
        upstream `intel/vllm:*-xpu` image's compressed-tensors W4A16
        MoE path goes through Marlin, which has no XPU kernel
        (`gptq_marlin_repack` not registered for XPU). llm-scaler
        ships `--quantization sym_int4`, an IPEX/OneDNN-backed
        online INT4 (GGML Q4_0) MoE path that actually serves on
        BMG-G31.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      description = ''
        HuggingFace model id to serve (positional arg of
        `vllm serve`). For `--quantization sym_int4` this must be
        the unquantized BF16 base — IPEX packs the weights to INT4
        at load time. Pre-quantized AWQ/GPTQ/compressed-tensors W4A16
        MoE weights all hit the Marlin XPU dead-end as of 2026-04-29.
      '';
      example = "Qwen/Qwen3.6-35B-A3B";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = ''
        Served-model id over the OpenAI-compatible API
        (`--served-model-name`). Set to the same value as `model` if
        you want vLLM to expose the raw HF repo id.
      '';
      example = "qwen3.6-35b-a3b";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "float16";
      description = ''
        Data type for model weights. `sym_int4` requires `float16`
        (BF16 is rejected by the IPEX quant path).
      '';
    };

    quantization = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "sym_int4";
      description = ''
        vLLM `--quantization` flag value, or null to skip the flag.
        `sym_int4` is the only XPU-MoE-capable INT4 path in this
        image as of b8.2.
      '';
    };

    kvCacheDtype = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "fp8";
      description = ''
        vLLM `--kv-cache-dtype` value, or null to skip the flag.
        Defaults to `fp8` — doubles KV-cache headroom (e.g. 103k →
        207k tokens for Qwen3.6-35B-A3B at 32k context) for ~2–3%
        per-stream throughput cost. Necessary headroom for
        concurrent agentic workloads where context grows over time.
        Set to null to fall back to model-precision KV cache.
      '';
    };

    maxModelLen = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 32768;
      description = "Maximum model context length. Reduces VRAM when set below model default.";
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "Fraction of XPU VRAM vLLM may use.";
    };

    enforceEager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass `--enforce-eager`. Required, not optional: without it
        Dynamo trips on IPEX's pybind11 C-extension `_has_xmx`
        called from `qwen3_5.linear_attn.forward_xpu`, raising
        `torch._dynamo.exc.Unsupported`. Eager-mode throughput is
        at the kernel ceiling anyway (20 tok/s single, 868 tok/s
        64-way agg), so the inductor path wouldn't add anything.
      '';
    };

    reasoningParser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Pass `--reasoning-parser <value>` (e.g. `qwen3`).";
      example = "qwen3";
    };

    reasoningParserPlugin = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a Python file implementing a custom reasoning parser. The
        file is bind-mounted read-only into the container and passed as
        `--reasoning-parser-plugin`. The plugin must register itself via
        `ReasoningParserManager.register_module("name")`; that name then
        goes in `reasoningParser`.
      '';
    };

    limitMmPerPrompt = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        JSON attrset passed to `--limit-mm-per-prompt`. For text-only
        use of a multimodal checkpoint (Qwen3.6-35B-A3B is VL-tagged
        even though we only want the text path), set
        `{ image = 0; video = 0; }` to skip the multimodal-budget
        init that otherwise calls
        `Qwen2VLImageProcessor.max_pixels` and crashes on newer
        transformers.
      '';
      example = lib.literalExpression ''{ image = 0; video = 0; }'';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional command-line arguments appended to `vllm serve`.";
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
        OneCCL env vars. With the default xccl backend even at
        world_size=1 the warmup `all_reduce` hangs unless IPC is
        forced to sockets and the launcher is told there's no MPI
        ranks. These four make single-card init complete in seconds
        instead of indefinitely.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file with secrets (e.g. HF_TOKEN).";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vllm";
      description = "Directory for HuggingFace model cache (bind-mounted at `/cache`).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "vllm";
      description = "User account that owns `cacheDir`.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "vllm";
      description = "Group that owns `cacheDir`.";
    };
  };

  config = lib.mkIf (topCfg.enable && topCfg.backend == "vllm") {
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

    virtualisation.oci-containers.containers.local-llm = {
      autoStart = true;
      image = "${cfg.containerImage.imageName}:${cfg.containerImage.imageTag}";
      imageFile = cfg.containerImage;

      environment =
        {HF_HOME = "/cache";}
        // cfg.cclEnv;

      volumes =
        [
          "${cfg.cacheDir}:/cache"
        ]
        ++ lib.optionals (cfg.reasoningParserPlugin != null) [
          "${cfg.reasoningParserPlugin}:/etc/vllm/reasoning_parser.py:ro"
        ];

      ports = ["${topCfg.host}:${toString topCfg.port}:8000"];

      extraOptions = [
        "--device=/dev/dri"
        "--ipc=host"
      ];

      # llm-scaler-vllm ships ENTRYPOINT=["bash","-c","vllm serve"]
      # which would prepend "vllm serve" to whatever cmd we pass.
      # Override entrypoint so cfg.cmd is the full argv we control.
      entrypoint = "/bin/bash";
      cmd = let
        serveArgs =
          [
            "serve"
            cfg.model
            "--served-model-name"
            cfg.alias
            "--dtype"
            cfg.dtype
            "--port"
            "8000"
            "--gpu-memory-utilization"
            (toString cfg.gpuMemoryUtilization)
          ]
          ++ lib.optionals (cfg.maxModelLen != null) [
            "--max-model-len"
            (toString cfg.maxModelLen)
          ]
          ++ lib.optionals (cfg.quantization != null) [
            "--quantization"
            cfg.quantization
          ]
          ++ lib.optionals (cfg.kvCacheDtype != null) [
            "--kv-cache-dtype"
            cfg.kvCacheDtype
          ]
          ++ lib.optionals cfg.enforceEager ["--enforce-eager"]
          ++ lib.optionals (cfg.reasoningParser != null) [
            "--reasoning-parser"
            cfg.reasoningParser
          ]
          ++ lib.optionals (cfg.reasoningParserPlugin != null) [
            "--reasoning-parser-plugin"
            "/etc/vllm/reasoning_parser.py"
          ]
          ++ lib.optionals (cfg.limitMmPerPrompt != null) [
            "--limit-mm-per-prompt"
            (builtins.toJSON cfg.limitMmPerPrompt)
          ]
          ++ cfg.extraArgs;
      in [
        "-lc"
        "cd /llm && exec vllm ${lib.escapeShellArgs serveArgs}"
      ];
    };

    systemd.services.podman-local-llm = lib.mkIf (cfg.environmentFile != null) {
      serviceConfig.EnvironmentFile = cfg.environmentFile;
    };
  };
}
