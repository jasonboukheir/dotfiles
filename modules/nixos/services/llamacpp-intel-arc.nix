{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  cfg = config.services.llamacpp-intel-arc;

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

  serverArgs =
    [
      "--model"
      "${cfg.modelDir}/${cfg.modelFile}"
      "--alias"
      cfg.alias
      "--host"
      cfg.host
      "--port"
      (toString cfg.port)
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
in {
  options.services.llamacpp-intel-arc = {
    enable = lib.mkEnableOption "patched llama-server (Intel SYCL, Battlemage)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llamacpp-intel-arc-server;
      defaultText = lib.literalExpression "pkgs.llamacpp-intel-arc-server";
      description = ''
        Derivation containing `bin/llama-server` plus its companion
        `lib/lib*.so*` files, autopatched against `intel-oneapi.base`
        and `level-zero` so it runs natively. The version is stamped
        per build from the input directory's narHash so each rebuild
        produces a uniquely-named store path.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Port to bind. Bound to `host` only (not 0.0.0.0).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind. Default localhost-only — exposure goes through LiteLLM.";
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      description = ''
        Directory containing the GGUF file. Read by the service via
        systemd `ReadOnlyPaths` — pick whatever cache the model is
        already in (e.g. `/home/jasonbk/.cache/llamacpp/models`).
      '';
      example = "/home/jasonbk/.cache/llamacpp/models";
    };

    modelFile = lib.mkOption {
      type = lib.types.str;
      description = "GGUF filename inside `modelDir` (e.g. `Qwen3.6-35B-A3B-UD-Q4_K_M.gguf`).";
      example = "Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = "Served-model id over the OpenAI-compatible API (used by LiteLLM as the upstream model name).";
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

  config = lib.mkIf cfg.enable {
    allowUnfreePackageNames = ["intel-oneapi-base-toolkit"];

    systemd.services.llamacpp-intel-arc = {
      description = "llama-server (Intel SYCL, Battlemage)";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];

      environment =
        {
          LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.level-zero] + ":/run/opengl-driver/lib";
        }
        // lib.optionalAttrs cfg.attnRotIso {
          LLAMA_ATTN_ROT_ISO = "1";
        };

      serviceConfig = {
        ExecStart = utils.escapeSystemdExecArgs (
          ["${cfg.package}/bin/llama-server"] ++ serverArgs
        );
        DynamicUser = true;
        SupplementaryGroups = ["video" "render"];
        DeviceAllow = ["/dev/dri/* rw"];
        PrivateDevices = false;
        BindReadOnlyPaths = [cfg.modelDir];
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
