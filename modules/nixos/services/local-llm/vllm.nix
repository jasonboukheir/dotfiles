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

    maxNumSeqs = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Pass `--max-num-seqs <n>`. Caps the engine's concurrent
        sequence count, which bounds the worst-case shape used by
        vLLM's startup memory-profile pass (max_num_seqs ×
        max_num_batched_tokens). Lower values trade concurrency
        ceiling for a smaller activation peak — the difference between
        OOM at engine init and clean startup when GPU VRAM is shared
        with other models. `null` keeps vLLM's default (256).
      '';
    };

    gpuMemoryUtilization = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "Fraction of XPU VRAM vLLM may use.";
    };

    speculativeConfig = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = ''
        JSON attrset passed to `--speculative-config`. Enables
        speculative decoding (MTP / EAGLE / draft-target). For MTP-K3
        on a hybrid-GDN model, set
        `{ method = "mtp"; num_speculative_tokens = 3; }` — the K
        value must match `cudagraphCaptureSizes` (verify-pass shape =
        1 + K, so K=3 wants `[1 4]`). Requires the GDN spec-decode
        dispatcher patch (image tag `spec-fix-b6a544b82` or later) on
        XPU; otherwise the SYCL `gdn_attention` kernel asserts on the
        first verify pass.
      '';
      example = lib.literalExpression ''{ method = "mtp"; num_speculative_tokens = 3; }'';
    };

    enforceEager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Pass `--enforce-eager`. Required on the legacy
        intel/llm-scaler-vllm image because Dynamo trips on IPEX's
        pybind11 C-extension `_has_xmx` called from
        `qwen3_5.linear_attn.forward_xpu`. The IPEX-free
        vllm-xpu-int4-tq image makes Dynamo + Inductor + XPU graph
        capture (PIECEWISE) viable; turning eager off there lifts
        single-stream from ~20 tok/s to ~58 tok/s on
        Qwen3.6-35B-A3B (matching llama.cpp's hand-tuned SYCL
        pipeline). Pair with `enableXpuGraph` and
        `cudagraphCaptureSizes`.
      '';
    };

    enableXpuGraph = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Set `VLLM_XPU_ENABLE_XPU_GRAPH=1` in the container env. This
        is what actually captures the decode loop into a Level Zero
        command list — torch.compile alone helps a little, but the
        ~3x single-stream win comes from graph replay collapsing the
        hundreds of per-kernel CPU dispatches into one submission
        per token. No-op while `enforceEager = true`.
      '';
    };

    cudagraphCaptureSizes = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.int);
      default = null;
      description = ''
        Batch sizes to capture into PIECEWISE XPU graphs (passed via
        `--compilation-config '{"cudagraph_capture_sizes":[…]}'`).
        Defaults to `null` which lets vLLM pick — typically 19 sizes
        from 1 to 128 costing ~7 GiB of VRAM, which OOMs the KV
        cache budget on a 32 GiB B70 alongside a 20 GiB model. Set
        e.g. `[ 1 2 4 8 ]` (~1.4 GiB) to cover single-stream + light
        concurrency; beyond the largest captured size vLLM falls
        back to eager-style submission. Ineffective unless
        `enableXpuGraph = true` and `enforceEager = false`.
      '';
      example = lib.literalExpression "[ 1 2 4 8 ]";
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

    workingDir = lib.mkOption {
      type = lib.types.str;
      default = "/llm";
      description = ''
        cwd to chdir into before exec'ing vllm. The default `/llm` is
        where intel/llm-scaler-vllm puts its checked-out source tree.
        Other images (e.g. upstream `vllm/docker/Dockerfile.xpu` which
        WORKDIRs to `/workspace/vllm`) need a different value.
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
        // cfg.cclEnv
        // lib.optionalAttrs cfg.enableXpuGraph {
          VLLM_XPU_ENABLE_XPU_GRAPH = "1";
        };

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
          ++ lib.optionals (cfg.maxNumSeqs != null) [
            "--max-num-seqs"
            (toString cfg.maxNumSeqs)
          ]
          ++ lib.optionals (cfg.speculativeConfig != null) [
            "--speculative-config"
            (builtins.toJSON cfg.speculativeConfig)
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
          ++ lib.optionals (cfg.cudagraphCaptureSizes != null) [
            "--compilation-config"
            (builtins.toJSON {cudagraph_capture_sizes = cfg.cudagraphCaptureSizes;})
          ]
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
        "cd ${cfg.workingDir} && exec vllm ${lib.escapeShellArgs serveArgs}"
      ];
    };

    systemd.services.podman-local-llm = lib.mkIf (cfg.environmentFile != null) {
      serviceConfig.EnvironmentFile = cfg.environmentFile;
    };
  };
}
