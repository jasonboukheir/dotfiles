{...}: {
  services.speaches = {
    enable = true;
    preloadModels = [
      "Systran/faster-whisper-large-v3"
      "speaches-ai/Kokoro-82M-v1.0-ONNX"
    ];
    environment = {
      LOG_LEVEL = "info";
      ENABLE_UI = "False";
    };
  };
}
