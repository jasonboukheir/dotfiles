{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-embedding;
in {
  sunnycareboo.ports.allocate.local-embedding = lib.mkIf cfg.enable 8001;

  # Qwen3-Embedding-0.6B Q8_0: 639 MB on disk, ~700 MB VRAM at runtime,
  # 1024-dim output, 32K context, last-token pooling. Fits comfortably
  # alongside the vLLM Qwen3.6-35B chat backend on the 32 GiB Arc B70.
  # Top of MTEB v2 in its size class as of 2026-04-29.
  services.local-embedding = {
    enable = true;
    host = "127.0.0.1";
    port = lib.mkIf cfg.enable config.sunnycareboo.ports.values.local-embedding;

    alias = "qwen3-embedding-0.6b";
    modelFile = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    modelUrl = "https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/370f27d7550e0def9b39c1f16d3fbaa13aa67728/Qwen3-Embedding-0.6B-Q8_0.gguf";

    pooling = "last";
    contextSize = 8192;
  };
}
