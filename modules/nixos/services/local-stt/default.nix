{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.local-stt;

  stateDir = "/var/lib/local-stt";

  fetchModelScript = pkgs.writeShellApplication {
    name = "local-stt-fetch-model";
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
      "--host"
      "0.0.0.0"
      "--port"
      "8080"
      "--threads"
      (toString cfg.threads)
      "--language"
      cfg.language
      "--inference-path"
      "/v1/audio/transcriptions"
    ]
    ++ cfg.extraArgs;

  serverArgsShell = lib.escapeShellArgs serverArgs;
in {
  options.services.local-stt = {
    enable = lib.mkEnableOption "GPU-backed STT server (whisper.cpp, Intel SYCL)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.whispercpp-intel-arc-server;
      defaultText = lib.literalExpression "pkgs.whispercpp-intel-arc-server";
      description = ''
        Vendored `whisper-server` derivation. Bind-mounted into the
        container at `/whisper` and resolved through the image's
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
      default = 8002;
      description = ''
        Host-side port that the OpenAI-compatible
        `/v1/audio/transcriptions` endpoint is published on.
      '';
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/models";
      defaultText = lib.literalExpression "\"\${stateDir}/models\"";
      description = "Host directory holding the GGML model; mounted read-only at `/models`.";
    };

    modelFile = lib.mkOption {
      type = lib.types.str;
      description = "GGML filename inside `modelDir`.";
      example = "ggml-large-v3-turbo-q5_0.bin";
    };

    modelUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If set, an `ExecStartPre` fetches the GGML model into
        `modelDir/modelFile` when missing. Resumable via
        `curl --continue-at -` with an atomic rename from `.partial`.
      '';
    };

    threads = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "CPU helper threads for non-SYCL ops (mel spectrogram, sampling).";
    };

    language = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        Default spoken-language code (e.g. `en`, `de`, `fr`) or `auto`
        for per-request detection. Clients can override via the
        OpenAI `language` form-data field.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional flags appended to the whisper-server command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.local-stt = {
      autoStart = true;
      image = "${cfg.containerImage.imageName}:${cfg.containerImage.imageTag}";
      imageFile = cfg.containerImage;

      environment = {
        SETVARS_COMPLETED = "0";
      };

      volumes = [
        "${cfg.package}:/whisper:ro"
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
          + "export LD_LIBRARY_PATH=/whisper/lib:\${LD_LIBRARY_PATH:-} && "
          + "exec /whisper/bin/whisper-server ${serverArgsShell}")
      ];
    };

    systemd.services.podman-local-stt = lib.mkIf (cfg.modelUrl != null) {
      serviceConfig.ExecStartPre = [
        "${fetchModelScript}/bin/local-stt-fetch-model"
      ];
    };
  };
}
