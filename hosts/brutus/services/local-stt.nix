{
  config,
  lib,
  ...
}: let
  cfg = config.services.local-stt;
in {
  sunnycareboo.ports.allocate.local-stt = lib.mkIf cfg.enable 8002;

  # whisper-large-v3-turbo Q5_0: 574 MB on disk, ~700 MB VRAM, 4 decoder
  # layers (vs 32 in large-v3) for ~6x faster decode at near-identical
  # WER. Multilingual. Fits alongside the vLLM Qwen3.6-35B chat backend
  # and the Qwen3-Embedding-0.6B retrieval backend on the 32 GiB Arc B70.
  services.local-stt = {
    enable = true;
    host = "127.0.0.1";
    port = lib.mkIf cfg.enable config.sunnycareboo.ports.values.local-stt;

    modelFile = "ggml-large-v3-turbo-q5_0.bin";
    modelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo-q5_0.bin";

    language = "auto";
  };
}
