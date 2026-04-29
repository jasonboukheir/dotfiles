{
  config,
  lib,
  ...
}: {
  sunnycareboo.ports.allocate.speaches = lib.mkIf config.services.speaches.enable 3500;
  services.speaches = {
    enable = true;
    port = config.sunnycareboo.ports.values.speaches;
    preloadModels = [
      "Systran/faster-whisper-large-v3"
      "speaches-ai/Kokoro-82M-v1.0-ONNX"
    ];
    environment = {
      LOG_LEVEL = "info";
      ENABLE_UI = "False";
      STT_MODEL_TTL = "3600";
      TTS_MODEL_TTL = "3600";
    };
  };
}
