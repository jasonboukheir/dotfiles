{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vllm;
in {
  options.services.vllm = {
    enable = lib.mkEnableOption "vLLM OpenAI-compatible inference server";

    model = lib.mkOption {
      type = lib.types.str;
      description = "HuggingFace model ID to serve";
      example = "meta-llama/Meta-Llama-3.1-8B-Instruct";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for the OpenAI-compatible API";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "xpu";
      description = "Device to run inference on (xpu, cpu)";
    };

    dtype = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = "Data type for model weights (auto, float16, bfloat16)";
    };

    maxModelLen = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Maximum model context length. Reduces VRAM usage when set below model default.";
      example = 4096;
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional command-line arguments passed to vLLM";
      example = ["--gpu-memory-utilization" "0.9" "--enforce-eager"];
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file containing secrets (e.g. HF_TOKEN)";
    };

    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/vllm";
      description = "Directory for HuggingFace model cache";
    };

    imageFile = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-vllm-image";
      description = "OCI image derivation for the vLLM container";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "vllm";
      description = "User account under which vLLM runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "vllm";
      description = "Group under which vLLM runs";
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

    virtualisation.oci-containers.containers.vllm = let
      imageTag = cfg.imageFile.imageTag;
      imageName = cfg.imageFile.imageName;
    in {
      autoStart = true;
      image = "${imageName}:${imageTag}";
      imageFile = cfg.imageFile;

      environment = {
        HF_HOME = "/cache";
      };

      volumes = [
        "${cfg.cacheDir}:/cache"
      ];

      ports = [
        "${toString cfg.port}:8000"
      ];

      extraOptions = [
        "--device=/dev/dri"
        "--ipc=host"
      ];

      cmd =
        [
          "--model" cfg.model
          "--device" cfg.device
          "--dtype" cfg.dtype
          "--port" "8000"
        ]
        ++ lib.optionals (cfg.maxModelLen != null) [
          "--max-model-len" (toString cfg.maxModelLen)
        ]
        ++ cfg.extraArgs;
    };

    systemd.services.podman-vllm = lib.mkIf (cfg.environmentFile != null) {
      serviceConfig.EnvironmentFile = cfg.environmentFile;
    };
  };
}
