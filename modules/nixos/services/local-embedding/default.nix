{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.local-embedding;

  stateDir = "/var/lib/local-embedding";

  fetchModelScript = pkgs.writeShellApplication {
    name = "local-embedding-fetch-model";
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

  serverArgs =
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
      "-1"
      "--batch-size"
      (toString cfg.batchSize)
      "--ubatch-size"
      (toString cfg.ubatchSize)
      "--parallel"
      (toString cfg.parallel)
      "--threads"
      (toString cfg.threads)
      "--embeddings"
      "--pooling"
      cfg.pooling
    ]
    ++ cfg.extraArgs;

  serverArgsShell = lib.escapeShellArgs serverArgs;
in {
  options.services.local-embedding = {
    enable = lib.mkEnableOption "GPU-backed embedding server (llama.cpp, Intel SYCL)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llamacpp-intel-arc-server;
      defaultText = lib.literalExpression "pkgs.llamacpp-intel-arc-server";
      description = ''
        Vendored `llama-server` derivation. Bind-mounted into the
        container at `/llama` and resolved through the image's
        oneAPI / level-zero / NEO / IGC stack via `setvars.sh`,
        same pattern as `services.local-llm.llamacpp`.
      '';
    };

    containerImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-vllm-image";
      description = "OCI image used as the SYCL runtime stack.";
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
        endpoint is published on.
      '';
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/models";
      defaultText = lib.literalExpression "\"\${stateDir}/models\"";
      description = "Host directory holding the GGUF; mounted read-only at `/models`.";
    };

    modelFile = lib.mkOption {
      type = lib.types.str;
      description = "GGUF filename inside `modelDir`.";
      example = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    };

    modelUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If set, an `ExecStartPre` fetches the GGUF into
        `modelDir/modelFile` when missing. Resumable via
        `curl --continue-at -` with an atomic rename from `.partial`.
      '';
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = "Served-model id over the OpenAI-compatible API.";
      example = "qwen3-embedding-0.6b";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 8192;
      description = ''
        Maximum tokens per embedding request. Caps the largest chunk
        a client may submit in one call. Embedding models don't
        autoregress so the KV-cache cost per slot is small; oversizing
        here is cheap.
      '';
    };

    batchSize = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = "Logical prompt-processing chunk size (`--batch-size`).";
    };

    ubatchSize = lib.mkOption {
      type = lib.types.int;
      default = 512;
      description = "Physical forward-pass batch (`--ubatch-size`).";
    };

    parallel = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = ''
        `--parallel` slots — concurrent in-flight embedding requests.
        Open WebUI ingest of a multi-chunk document fans out into
        several /v1/embeddings calls; four slots is enough for that
        burst without much KV pressure on a 0.6B-class model.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "CPU helper threads.";
    };

    pooling = lib.mkOption {
      type = lib.types.enum ["none" "mean" "cls" "last" "rank"];
      default = "last";
      description = ''
        Pooling strategy. Decoder-only embedders like Qwen3-Embedding
        use `last`; BERT-style encoders use `cls` or `mean`.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional flags appended to the llama-server command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.local-embedding = {
      autoStart = true;
      image = "${cfg.containerImage.imageName}:${cfg.containerImage.imageTag}";
      imageFile = cfg.containerImage;

      environment = {
        SETVARS_COMPLETED = "0";
      };

      volumes = [
        "${cfg.package}:/llama:ro"
        "${cfg.modelDir}:/models:ro"
      ];

      ports = ["${cfg.host}:${toString cfg.port}:8080"];

      extraOptions = [
        "--device=/dev/dri"
        "--shm-size=1g"
      ];

      entrypoint = "/bin/bash";
      cmd = [
        "-lc"
        (". /opt/intel/oneapi/setvars.sh --force >/dev/null && "
          + "export LD_LIBRARY_PATH=/llama/lib:\${LD_LIBRARY_PATH:-} && "
          + "exec /llama/bin/llama-server ${serverArgsShell}")
      ];
    };

    systemd.services.podman-local-embedding = lib.mkIf (cfg.modelUrl != null) {
      serviceConfig.ExecStartPre = [
        "${fetchModelScript}/bin/local-embedding-fetch-model"
      ];
    };
  };
}
