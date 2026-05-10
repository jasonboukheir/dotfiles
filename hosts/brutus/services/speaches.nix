{
  config,
  lib,
  ...
}: {
  homelab.ports.allocate.speaches = lib.mkIf config.services.speaches.enable 3500;
  services.speaches = {
    enable = true;
    port = config.homelab.ports.values.speaches;
    # STT moved to GPU via services.vllm-xpu.instances.stt
    # (whisper-large-v3-turbo on the native vllm-xpu build).
    # Speaches now hosts only Kokoro TTS — fast enough on CPU at ~10x
    # realtime that GPU offload doesn't pay back the engineering cost.
    preloadModels = [
      "speaches-ai/Kokoro-82M-v1.0-ONNX"
    ];
    environment = {
      LOG_LEVEL = "info";
      ENABLE_UI = "False";
      TTS_MODEL_TTL = "3600";
    };
  };
}
