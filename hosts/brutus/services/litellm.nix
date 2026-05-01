{
  lib,
  config,
  ...
}: let
  cfg = config.services.litellm;
  localLlm = config.services.local-llm;
  localEmbedding = config.services.local-embedding;
  localStt = config.services.local-stt;
  speaches = config.services.speaches;
  port = config.homelab.ports.values.litellm;

  localLlmBase = "http://${localLlm.host}:${toString localLlm.port}/v1";
  localEmbeddingBase = "http://${localEmbedding.host}:${toString localEmbedding.port}/v1";
  localSttBase = "http://${localStt.host}:${toString localStt.port}/v1";
  speachesBase = "http://${speaches.host}:${toString speaches.port}/v1";

  qwenVariant = {
    name,
    enableThinking,
    extra ? {},
  }: {
    model_name = name;
    litellm_params =
      {
        model = "openai/${localLlm.alias}";
        api_base = localLlmBase;
        api_key = "sk-noop";
        extra_body = {
          chat_template_kwargs = {
            enable_thinking = enableThinking;
          };
        };
      }
      // extra;
    model_info = {
      mode = "chat";
      supports_reasoning = enableThinking;
    };
  };
in {
  homelab.ports.allocate.litellm = lib.mkIf cfg.enable 3200;
  services.litellm = {
    enable = true;
    port = port;
    environment = {
      DATABASE_URL = "postgresql://litellm@localhost:5432/litellm";
    };
    environmentFile = config.age.secrets."litellm/env".path;

    settings.model_list =
      lib.optionals localLlm.enable [
        (qwenVariant {
          name = "qwen3.6-fast";
          enableThinking = false;
        })
        (qwenVariant {
          name = "qwen3.6-deep";
          enableThinking = true;
          extra.max_tokens = 16384;
        })
      ]
      ++ lib.optionals localEmbedding.enable [
        {
          model_name = "text-embedding-qwen3";
          litellm_params = {
            model = "openai/${localEmbedding.alias}";
            api_base = localEmbeddingBase;
            api_key = "sk-noop";
          };
          model_info = {
            mode = "embedding";
            output_vector_size = 1024;
          };
        }
      ]
      ++ lib.optionals localStt.enable [
        {
          model_name = "whisper-1";
          litellm_params = {
            model = "openai/whisper-1";
            api_base = localSttBase;
            api_key = "sk-noop";
          };
          model_info = {mode = "audio_transcription";};
        }
      ]
      ++ lib.optionals speaches.enable [
        {
          model_name = "tts-1";
          litellm_params = {
            model = "openai/tts-1";
            api_base = speachesBase;
            api_key = "sk-noop";
          };
          model_info = {mode = "audio_speech";};
        }
      ];
  };

  age.secrets."litellm/env" = lib.mkIf cfg.enable {
    file = ../secrets/litellm/env.age;
  };

  services.postgresql = lib.mkIf cfg.enable {
    ensureUsers = [
      {
        name = "litellm";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "litellm"
    ];
  };

  homelab.services.llm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
  };
}
