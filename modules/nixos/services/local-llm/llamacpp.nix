{
  config,
  lib,
  pkgs,
  ...
}: let
  topCfg = config.services.local-llm;
  cfg = topCfg.llamacpp;

  stateDirName = "llamacpp";
  stateDir = "/var/lib/${stateDirName}";

  validKvTypes = [
    "f32"
    "f16"
    "bf16"
    "q8_0"
    "q4_0"
    "q4_1"
    "iq4_nl"
    "q5_0"
    "q5_1"
  ];

  flashFlag =
    if cfg.flashAttn
    then "on"
    else "off";

  fetchModelScript = pkgs.writeShellApplication {
    name = "local-llm-llamacpp-fetch-model";
    runtimeInputs = [pkgs.coreutils pkgs.curl];
    text = ''
      target="${cfg.modelDir}/${cfg.modelFile}"
      if [ -f "$target" ]; then
        exit 0
      fi
      mkdir -p "${cfg.modelDir}"
      echo "fetching ${cfg.modelFile} from ${toString cfg.modelUrl}"
      curl --location --fail --retry 5 --retry-delay 5 --continue-at - \
        --output "$target.partial" \
        "${toString cfg.modelUrl}"
      mv "$target.partial" "$target"
    '';
  };

  # The server binds 0.0.0.0:8080 inside the container; podman publishes
  # that to ${topCfg.host}:${topCfg.port} on the host.
  containerServerArgs =
    [
      "--model"
      "/models/${cfg.modelFile}"
      "--alias"
      cfg.alias
      "--host"
      "0.0.0.0"
      "--port"
      "8080"
      "--ctx-size"
      (toString cfg.contextSize)
      "--n-gpu-layers"
      (toString cfg.nGpuLayers)
      "--batch-size"
      (toString cfg.nBatch)
      "--ubatch-size"
      (toString cfg.nUbatch)
      "--parallel"
      (toString cfg.parallel)
      "--threads"
      (toString cfg.threads)
      "--cache-type-k"
      cfg.cacheTypeK
      "--cache-type-v"
      cfg.cacheTypeV
      "--flash-attn"
      flashFlag
      "--metrics"
    ]
    ++ cfg.samplingArgs
    ++ cfg.extraArgs;

  containerServerArgsShell = lib.escapeShellArgs containerServerArgs;
in {
  options.services.local-llm.llamacpp = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llamacpp-intel-arc-server;
      defaultText = lib.literalExpression "pkgs.llamacpp-intel-arc-server";
      description = ''
        Vendored `llama-server` derivation. The binary is bind-mounted
        into the container at `/llama` in its raw (un-autopatched) form
        and `setvars.sh` is sourced inside the container so resolution
        goes through the image's matching oneAPI / level-zero / NEO /
        IGC stack.
      '';
    };

    containerImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-vllm-image";
      description = ''
        OCI image used as the runtime stack. Must contain
        `/opt/intel/oneapi/setvars.sh` and a matching
        `libze_intel_gpu` / `libigc` / `libigdfcl` set under `/usr/lib`.
      '';
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/models";
      defaultText = lib.literalExpression "\"\${stateDir}/models\"";
      description = ''
        Directory containing the GGUF file. Bind-mounted read-only at
        `/models` inside the container. Default lives under
        `/var/lib/llamacpp/models` to match the historical state-dir
        layout.
      '';
    };

    modelFile = lib.mkOption {
      type = lib.types.str;
      description = "GGUF filename inside `modelDir` (e.g. `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf`).";
      example = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    };

    modelUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If set, an `ExecStartPre` on the podman unit fetches the GGUF
        into `modelDir/modelFile` when the file is missing. Resumable
        via `curl --continue-at -`; an atomic rename from `.partial`
        avoids leaving a half-written file behind on interruption.

        Typical Hugging Face form:
        `https://huggingface.co/<user>/<repo>/resolve/main/<file>`.
        Public repos work without auth; gated repos would need an
        `Authorization` header which this option does not currently
        plumb through.
      '';
      example = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = "Served-model id over the OpenAI-compatible API.";
      example = "qwen3.6-35b-a3b-q4km";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 32768;
      description = "Total `--ctx-size` divided across `parallel` slots.";
    };

    nGpuLayers = lib.mkOption {
      type = lib.types.int;
      default = -1;
      description = "Layers to offload to the XPU. -1 = all.";
    };

    nBatch = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = "Logical prompt-processing chunk size (`--batch-size`).";
    };

    nUbatch = lib.mkOption {
      type = lib.types.int;
      default = 512;
      description = "Physical forward-pass batch (`--ubatch-size`).";
    };

    parallel = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = ''
        `--parallel` slots — concurrent in-flight requests, each with
        its own slice of the KV-cache budget. Two is enough for the
        intended 1-2 user use case; higher values cost KV-VRAM
        proportional to `parallel`.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = "CPU helper threads.";
    };

    flashAttn = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Pass `--flash-attn on`.";
    };

    cacheTypeK = lib.mkOption {
      type = lib.types.enum validKvTypes;
      default = "q4_0";
      description = ''
        K cache quantization. Q4_0 is operationally indistinguishable from
        FP16 above 1K context (KL ≈ 0.005 nats/tok per
        `results/kl-iso-20260426/SUMMARY.md`) thanks to the
        Walsh-Hadamard rotation that upstream master applies
        automatically when this is quantized.
      '';
    };

    cacheTypeV = lib.mkOption {
      type = lib.types.enum validKvTypes;
      default = "q4_0";
      description = "V cache quantization. See cacheTypeK.";
    };

    attnRotIso = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If true, sets `LLAMA_ATTN_ROT_ISO=1` to swap the default
        Walsh-Hadamard KV-rotation for the block-diagonal quaternion
        rotation introduced in our local fork. Phase 2b showed iso loses
        to WHT at Q4_0 on Qwen3.6 — leave off in production.
      '';
    };

    samplingArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["--temp" "0.6" "--top-p" "0.95" "--top-k" "20"];
      description = ''
        Default sampling args. Unsloth's "Thinking — coding" preset for
        Qwen 3.6 is temp 0.6 / top-p 0.95 / top-k 20 / presence-penalty 0.
        API callers can override per request; these are only the floor.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional flags appended to the llama-server command line.";
    };
  };

  # Directory creation is handled by the fetch-model ExecStartPre
  # (`mkdir -p`) so we deliberately avoid `systemd.tmpfiles.rules`
  # for `${stateDir}`, which a prior `DynamicUser` +
  # `StateDirectory=llamacpp` layout materialized as a symlink to
  # `/var/lib/private/llamacpp` — re-asserting ownership/mode on
  # that path would replace the symlink and orphan the existing
  # 20+ GiB model file.
  config = lib.mkIf (topCfg.enable && topCfg.backend == "llamacpp") {
    virtualisation.oci-containers.containers.local-llm = {
      autoStart = true;
      image = "${cfg.containerImage.imageName}:${cfg.containerImage.imageTag}";
      imageFile = cfg.containerImage;

      environment =
        {
          SETVARS_COMPLETED = "0";
        }
        // lib.optionalAttrs cfg.attnRotIso {
          LLAMA_ATTN_ROT_ISO = "1";
        };

      volumes = [
        "${cfg.package}:/llama:ro"
        "${cfg.modelDir}:/models:ro"
      ];

      ports = ["${topCfg.host}:${toString topCfg.port}:8080"];

      extraOptions = [
        "--device=/dev/dri"
        "--shm-size=4g"
      ];

      entrypoint = "/bin/bash";
      cmd = [
        "-lc"
        (". /opt/intel/oneapi/setvars.sh --force >/dev/null && "
          + "export LD_LIBRARY_PATH=/llama/lib:\${LD_LIBRARY_PATH:-} && "
          + "exec /llama/bin/llama-server ${containerServerArgsShell}")
      ];
    };

    # Hook the auto-generated podman unit to fetch the model first.
    # oci-containers sets TimeoutStartSec=0 (infinite) by default,
    # which already accommodates the 20+ GiB weight load.
    systemd.services.podman-local-llm = lib.mkIf (cfg.modelUrl != null) {
      serviceConfig.ExecStartPre = [
        "${fetchModelScript}/bin/local-llm-llamacpp-fetch-model"
      ];
    };
  };
}
