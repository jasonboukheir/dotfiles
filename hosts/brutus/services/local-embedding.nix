{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-embedding;
in {
  sunnycareboo.ports.allocate.local-embedding = lib.mkIf cfg.enable 8001;

  # Qwen3-Embedding-0.6B BF16: ~1.2 GiB on disk, served by vLLM-XPU
  # in pooling-only mode. 1024-dim output, last-token pooling
  # (vLLM auto-detects from the repo's pooling config). 8K context.
  # Co-resident on the B70 with the Qwen3.6-35B-A3B chat instance —
  # chat at gpuMemoryUtilization 0.80, this at 0.07 (module default,
  # tightened from 0.10 once max-num-seqs landed — see module docs).
  # Top of MTEB v2 in its size class as of 2026-04-29.
  services.local-embedding = {
    enable = true;
    host = "127.0.0.1";
    port = lib.mkIf cfg.enable config.sunnycareboo.ports.values.local-embedding;

    model = "Qwen/Qwen3-Embedding-0.6B";
    alias = "qwen3-embedding-0.6b";
    maxModelLen = 8192;
  };
}
