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
      default = pkgs.intel-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-vllm-image";
      description = "OCI image derivation for the vLLM container.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      description = "HuggingFace model id to serve (positional arg of `vllm serve`).";
      example = "QuantTrio/Qwen3.6-35B-A3B-AWQ";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = ''
        Served-model id over the OpenAI-compatible API
        (`--served-model-name`). Set to the same value as `model` if
        you want vLLM to expose the raw HF repo id.
      '';
      example = "qwen3.6-35b-a3b-awq";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Data type for model weights (auto, float16, bfloat16).";
    };

    maxModelLen = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Maximum model context length. Reduces VRAM when set below model default.";
      example = 32768;
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional command-line arguments passed to vLLM.";
      example = ["--quantization" "awq" "--gpu-memory-utilization" "0.9"];
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

      environment = {
        HF_HOME = "/cache";
      };

      volumes = [
        "${cfg.cacheDir}:/cache"
      ];

      ports = ["${topCfg.host}:${toString topCfg.port}:8000"];

      extraOptions = [
        "--device=/dev/dri"
        "--ipc=host"
      ];

      # `intel/vllm:*-xpu` ships with `Cmd=["/bin/bash"]` and no
      # ENTRYPOINT, so without an explicit entrypoint here our `cmd`
      # argv[0] (`serve`) would be looked up as an executable.
      entrypoint = "/opt/venv/bin/vllm";
      cmd =
        [
          "serve"
          cfg.model
          "--served-model-name"
          cfg.alias
          "--dtype"
          cfg.dtype
          "--port"
          "8000"
        ]
        ++ lib.optionals (cfg.maxModelLen != null) [
          "--max-model-len"
          (toString cfg.maxModelLen)
        ]
        ++ cfg.extraArgs;
    };

    systemd.services.podman-local-llm = lib.mkIf (cfg.environmentFile != null) {
      serviceConfig.EnvironmentFile = cfg.environmentFile;
    };
  };
}
