{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.speaches;
  credLib = import ../lib/credentials.nix {inherit lib;};
  creds = credLib.mkCredentialsHelpers {inherit cfg pkgs;};
  defaultPort = 3500;

  preloadScript = lib.optionalString (cfg.preloadModels != []) ''
    echo "Preloading ${toString (builtins.length cfg.preloadModels)} model(s)..."
    ${lib.concatMapStringsSep "\n" (model: ''
      echo "Downloading ${model}..."
      ${lib.getExe' cfg.package "huggingface-cli"} download "${model}" --quiet || echo "Warning: failed to download ${model}"
    '') cfg.preloadModels}
  '';
in {
  options.services.speaches = {
    enable = lib.mkEnableOption "Speaches STT/TTS server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.speaches;
      description = "The speaches package to use.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Port to listen on.";
    };

    preloadModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["Systran/faster-whisper-large-v3" "speaches-ai/Kokoro-82M-v1.0-ONNX"];
      description = "HuggingFace model IDs to download before the service starts.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables for speaches (e.g. STT_MODEL_TTL, TTS_MODEL_TTL, LOG_LEVEL).";
    };

    credentials = credLib.mkCredentialsOption {
      description = "Credentials for Speaches (e.g. API_KEY).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.speaches = {
      description = "Speaches STT/TTS Server";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      path = [pkgs.ffmpeg];

      inherit (cfg) environment;

      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "speaches";
        CacheDirectory = "speaches";
        LoadCredential = creds.loadList;
        ExecStart = pkgs.writeShellScript "speaches-start" ''
          ${creds.exportScript}
          mkdir -p "$HF_HUB_CACHE"
          ${preloadScript}
          exec ${lib.getExe' cfg.package "uvicorn"} \
            --factory speaches.main:create_app \
            --host "${cfg.host}" \
            --port ${toString cfg.port}
        '';
        Environment = [
          "HOME=%S/speaches"
          "HF_HOME=%C/speaches/huggingface"
          "HF_HUB_CACHE=%C/speaches/huggingface/hub"
        ];
      };
    };
  };
}
