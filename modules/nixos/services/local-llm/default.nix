{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-llm;
in {
  imports = [
    ./llamacpp.nix
    ./vllm.nix
  ];

  options.services.local-llm = {
    enable = lib.mkEnableOption "enable local-llm";
    backend = lib.mkOption {
      type = lib.types.enum ["llamacpp" "vllm"];
      default = "llamacpp";
      description = ''
        Which local LLM backend should run. Backends are mutually
        exclusive — they would contend for `/dev/dri` and VRAM.

        - `"llamacpp"` — patched llama.cpp `llama-server` (SYCL),
          single-stream throughput leader.
        - `"vllm"` — Intel-built vLLM, better for concurrent serving.

        Backend-specific tunables live under
        `services.local-llm.<backend>.*`.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address that the active backend's published container
        port maps to on the host. Defaults to localhost-only — public
        exposure should go through LiteLLM.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = ''
        Host-side port that the active backend's OpenAI-compatible
        API is published on. The container-internal port differs per
        backend (llama.cpp listens on 8080 inside the container, vLLM
        on 8000) — that's fixed by the backend's binary, not user-tunable.
      '';
    };

    alias = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Served-model id of the active backend — what downstream
        consumers (LiteLLM) should use as the upstream model name.
        Computed from `services.local-llm.<backend>.alias`. Empty
        when the service is disabled.
      '';
    };
  };

  config = {
    services.local-llm.alias =
      if !cfg.enable
      then ""
      else if cfg.backend == "llamacpp"
      then cfg.llamacpp.alias
      else cfg.vllm.alias;
  };
}
