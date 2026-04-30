{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.open-webui;
  oidcCfg = config.services.pocket-id.ensureClients.open-webui;
  litellmCfg = config.services.litellm;
  domain = config.homelab.services.ai.domain;
  port = config.homelab.ports.values.open-webui;

  # Bypass nginx for same-host LiteLLM traffic: avoids TLS/buffering overhead
  # and keeps streaming responses unbuffered end-to-end.
  litellmBase = "http://${litellmCfg.host}:${toString litellmCfg.port}";

  litellmModels = litellmCfg.settings.model_list or [];
  modelByMode = mode: fallback:
    (lib.findFirst
      (m: (m.model_info.mode or null) == mode)
      {model_name = fallback;}
      litellmModels)
    .model_name;
  sttModel = modelByMode "audio_transcription" "whisper-1";
  ttsModel = modelByMode "audio_speech" "tts-1";
  embeddingModel = modelByMode "embedding" "text-embedding-3-small";
in {
  homelab.ports.allocate.open-webui = lib.mkIf cfg.enable 3100;
  allowUnfreePackageNames = lib.optionals cfg.enable ["open-webui"];
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.postgres;
    });
    port = port;
    environment = lib.mkMerge ([
        {
          ENABLE_PERSISTENT_CONFIG = "False";
          WEBUI_URL = "https://${domain}";
          ENV = "prod";
          CORS_ALLOW_ORIGIN = "https://${domain}";

          # database settings
          DATABASE_URL = "postgresql://open-webui/open-webui?host=/run/postgresql";

          # privacy settings
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "True";
          SCARF_NO_ANALYTICS = "True";
          ENABLE_VERSION_UPDATE_CHECK = "False";
          OFFLINE_MODE = "True";

          # pocket id oidc setup
          OPENID_PROVIDER_URL = "https://${config.homelab.services.id.domain}/.well-known/openid-configuration";
          OAUTH_CLIENT_ID = oidcCfg.settings.id;
          OAUTH_CODE_CHALLENGE_METHOD = "S256";
          OAUTH_PROVIDER_NAME = "Pocket ID";
          OPENID_REDIRECT_URL = "https://${domain}/oauth/oidc/callback";
          OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";
          ENABLE_OAUTH_SIGNUP = "True";

          # audio via litellm proxy
          AUDIO_STT_ENGINE = "openai";
          AUDIO_STT_OPENAI_API_BASE_URL = "${litellmBase}/v1";
          AUDIO_STT_MODEL = sttModel;
          AUDIO_TTS_ENGINE = "openai";
          AUDIO_TTS_OPENAI_API_BASE_URL = "${litellmBase}/v1";
          AUDIO_TTS_MODEL = ttsModel;
          AUDIO_TTS_VOICE = "alloy";

          # task generation: keep titles, drop the chatty ones that
          # spend chat-model slots on every keystroke / message turn.
          ENABLE_TAGS_GENERATION = "False";
          ENABLE_AUTOCOMPLETE_GENERATION = "False";
          ENABLE_FOLLOW_UP_GENERATION = "False";

          # cache /v1/models instead of re-polling every second
          ENABLE_BASE_MODELS_CACHE = "True";
          MODELS_CACHE_TTL = "300";

          # only LiteLLM is upstream; default-on Ollama probe spams the journal
          ENABLE_OLLAMA_API = "False";

          # search settings
          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "searxng";
          SEARXNG_QUERY_URL = "http://${config.homelab.services.search.domain}/search?q=<query>";
          WEB_SEARCH_RESULT_COUNT = "5";
          # bound SearXNG fan-out so upstream engines (Google/Bing/Brave)
          # don't rate-limit when OWUI splits a turn into multiple queries.
          WEB_SEARCH_CONCURRENT_REQUESTS = "2";
          # parallel URL fetches; different domains so no per-host rate risk.
          WEB_LOADER_CONCURRENT_REQUESTS = "20";

          # web search RAG: chunk + retrieve top-k to keep prompts within model context
          BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL = "False";
          RAG_EMBEDDING_ENGINE = "openai";
          RAG_EMBEDDING_MODEL = embeddingModel;
          RAG_EMBEDDING_MODEL_AUTO_UPDATE = "False";
          RAG_OPENAI_API_BASE_URL = "${litellmBase}/v1";
          RAG_EMBEDDING_BATCH_SIZE = "16";
        }
      ]
      ++ (lib.optional litellmCfg.enable {
        # OPENAI API
        OPENAI_API_BASE_URL = litellmBase;
      }));
    credentials = {
      "OPENAI_API_KEY" = config.age.secrets."open-webui/openaiApiKey".path;
      "AUDIO_STT_OPENAI_API_KEY" = config.age.secrets."open-webui/openaiApiKey".path;
      "AUDIO_TTS_OPENAI_API_KEY" = config.age.secrets."open-webui/openaiApiKey".path;
      "RAG_OPENAI_API_KEY" = config.age.secrets."open-webui/openaiApiKey".path;
      "WEBUI_SECRET_KEY" = config.age.secrets."open-webui/webuiSecretKey".path;
    };
  };

  services.pocket-id.ensureClients.open-webui = lib.mkIf cfg.enable {
    logo = ./open-webui-light.svg;
    darkLogo = ./open-webui-dark.svg;
    dependentServices = [config.systemd.services.open-webui.name];
    settings = {
      name = "Open WebUI";
      isPublic = true;
      launchURL = "https://${domain}";
      callbackURLs = [
        cfg.environment."OPENID_REDIRECT_URL"
      ];
    };
  };

  age.secrets = lib.mkIf cfg.enable {
    "open-webui/openaiApiKey".file = ../../secrets/open-webui/openaiApiKey.age;
    "open-webui/webuiSecretKey".file = ../../secrets/open-webui/webuiSecretKey.age;
  };

  # NGINX
  homelab.services.ai = lib.mkIf cfg.enable {
    enable = true;
    isExternal = true;
    proxyPass = "http://${cfg.host}:${toString cfg.port}";
    # Stream chat-completion SSE byte-by-byte; nginx's default buffering
    # re-chunks the stream and breaks markdown tokens across boundaries
    # (`**bold**` -> `**` + `bold` + `**`). Long timeouts cover slow first
    # tokens from web-search / tool-use turns. Socket.IO upgrades go through
    # the existing proxyWebsockets headers.
    extraConfig = ''
      proxy_buffering off;
      proxy_cache off;
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
    '';
  };

  # PostgreSQL
  services.postgresql = lib.mkIf cfg.enable {
    ensureUsers = [
      {
        name = "open-webui";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [
      "open-webui"
    ];
  };
}
