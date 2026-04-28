{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  cfg = config.services.llamacpp-intel-arc;

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
    name = "llamacpp-intel-arc-fetch-model";
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

  # Server CLI args. In container mode the host/port refer to the
  # in-container bind (host=0.0.0.0, port=8080) and the model path is
  # rewritten to the in-container mount.
  mkServerArgs = {
    modelPath,
    host,
    port,
  }:
    [
      "--model"
      modelPath
      "--alias"
      cfg.alias
      "--host"
      host
      "--port"
      (toString port)
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

  nativeServerArgs = mkServerArgs {
    modelPath = "${cfg.modelDir}/${cfg.modelFile}";
    host = cfg.host;
    port = cfg.port;
  };

  # Inside the container the binary lives at /llama, the model is
  # bind-mounted at /models, and the server binds 0.0.0.0:8080.
  # Podman publishes that to ${cfg.host}:${cfg.port} on the host.
  containerServerArgs = mkServerArgs {
    modelPath = "/models/${cfg.modelFile}";
    host = "0.0.0.0";
    port = 8080;
  };

  # Shell-quoted form for the container entrypoint (`bash -lc`).
  containerServerArgsShell = lib.escapeShellArgs containerServerArgs;
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
      default = "${stateDir}/models";
      defaultText = lib.literalExpression "\"\${stateDir}/models\"";
      description = ''
        Directory containing the GGUF file. Defaults to a `models/`
        subdirectory of the unit's `StateDirectory` (`/var/lib/llamacpp`)
        so the model lives next to the persisted NEO compiler cache and
        is owned by the dynamic UID via `StateDirectory` ownership
        migration. Override to point at a pre-existing cache.
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
        If set, the unit's `ExecStartPre` fetches the GGUF from this URL
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

    gpuRuntimeLibs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [pkgs.level-zero pkgs.intel-graphics-compiler];
      defaultText = lib.literalExpression "[pkgs.level-zero pkgs.intel-graphics-compiler]";
      description = ''
        Packages whose `lib/` is prepended to `LD_LIBRARY_PATH` so the
        SYCL/Level Zero stack can dlopen its runtime dependencies:

          - `level-zero` provides `libze_loader.so.1`. The Level Zero
            UR adapter inside oneAPI dlopens this by `SONAME` and only
            looks at oneAPI's own RUNPATH dirs, which do not contain it.
          - `intel-graphics-compiler` provides `libigc.so.2` and
            `libigdfcl.so.2`. `intel-compute-runtime` (the GPU driver
            shipped via `/run/opengl-driver/lib`) dlopens these to JIT
            SPIR-V to native Battlemage ISA; without them GMM init
            aborts in `gmm_helper/resource_info.cpp`.

        Override from the host config (e.g. `with pkgs-unstable; [...]`)
        so the versions match whatever `hardware.graphics.extraPackages`
        is using for `intel-compute-runtime`.

        Only used in native mode (`enableContainer = false`).
      '';
    };

    enableContainer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run the patched `llama-server` inside the `intel/vllm:*-xpu`
        OCI image instead of natively. The same vendored binary is
        bind-mounted into the container in its raw (un-autopatched)
        form, and `setvars.sh` is sourced so that resolution goes
        through the container's matching oneAPI/level-zero/NEO/IGC
        stack.

        Use this when the host's nixpkgs Intel GPU userspace stack
        (`intel-compute-runtime`, `intel-graphics-compiler`,
        `level-zero`) drifts ahead of what the AICSS binary was
        AOT-compiled against (oneAPI 2025.3 + the runtime libraries
        baked into the chosen container image), which has been
        observed to cost 5× decode throughput even though the
        binary still loads, all layers offload, and SYCL kernels
        for SSM_SCAN / GATED_DELTA_NET dispatch.
      '';
    };

    containerImage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.intel-vllm-image;
      defaultText = lib.literalExpression "pkgs.intel-vllm-image";
      description = ''
        OCI image used when `enableContainer = true`. Must contain
        `/opt/intel/oneapi/setvars.sh` and a matching `libze_intel_gpu`
        / `libigc` / `libigdfcl` set under `/usr/lib`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      allowUnfreePackageNames = ["intel-oneapi-base-toolkit"];
    }

    # Native variant — autopatched binary, NixOS Intel userspace stack.
    (lib.mkIf (!cfg.enableContainer) {
      systemd.services.llamacpp-intel-arc = {
        description = "llama-server (Intel SYCL, Battlemage)";
        wantedBy = ["multi-user.target"];
        after = ["network.target"];

        environment =
          {
            LD_LIBRARY_PATH = lib.makeLibraryPath cfg.gpuRuntimeLibs + ":/run/opengl-driver/lib";
            HOME = stateDir;
          }
          // lib.optionalAttrs cfg.attnRotIso {
            LLAMA_ATTN_ROT_ISO = "1";
          };

        serviceConfig = {
          ExecStart = utils.escapeSystemdExecArgs (
            ["${cfg.package}/bin/llama-server"] ++ nativeServerArgs
          );
          ExecStartPre = lib.mkIf (cfg.modelUrl != null) [
            "${fetchModelScript}/bin/llamacpp-intel-arc-fetch-model"
          ];
          TimeoutStartSec = "30min";
          DynamicUser = true;
          SupplementaryGroups = ["video" "render"];
          StateDirectory = stateDirName;
          WorkingDirectory = stateDir;
          ProtectSystem = false;
          ProtectHome = false;
          LockPersonality = false;
          RestrictSUIDSGID = false;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    })

    # Container variant — raw binary mounted into intel/vllm image,
    # which provides the matching oneAPI/level-zero/NEO/IGC stack.
    # Directory creation is handled by the fetch-model ExecStartPre
    # (`mkdir -p`) so we deliberately avoid `systemd.tmpfiles.rules`
    # for `${stateDir}`, which the prior native unit's `DynamicUser` +
    # `StateDirectory=llamacpp` materialized as a symlink to
    # `/var/lib/private/llamacpp` — re-asserting ownership/mode on
    # that path would replace the symlink and orphan the existing
    # 20+ GiB model file.
    (lib.mkIf cfg.enableContainer {
      virtualisation.oci-containers.containers.llamacpp-intel-arc = let
        rawPkg = cfg.package.raw;
        imageTag = cfg.containerImage.imageTag;
        imageName = cfg.containerImage.imageName;
      in {
        autoStart = true;
        image = "${imageName}:${imageTag}";
        imageFile = cfg.containerImage;

        environment =
          {
            SETVARS_COMPLETED = "0";
          }
          // lib.optionalAttrs cfg.attnRotIso {
            LLAMA_ATTN_ROT_ISO = "1";
          };

        volumes = [
          "${rawPkg}:/llama:ro"
          "${cfg.modelDir}:/models:ro"
        ];

        ports = ["${cfg.host}:${toString cfg.port}:8080"];

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
      systemd.services.podman-llamacpp-intel-arc = lib.mkIf (cfg.modelUrl != null) {
        serviceConfig.ExecStartPre = [
          "${fetchModelScript}/bin/llamacpp-intel-arc-fetch-model"
        ];
      };
    })
  ]);
}
