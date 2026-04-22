final: prev: let
  lib = final.lib;
  py = final.python312Packages;

  espeakngLoader = py.buildPythonPackage {
    pname = "espeakng-loader";
    version = "0.2.4";
    format = "wheel";
    src = final.fetchurl {
      url = "https://files.pythonhosted.org/packages/de/1e/25ec5ab07528c0fbb215a61800a38eca05c8a99445515a02d7fa5debcb32/espeakng_loader-0.2.4-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-CHIbryfRPUYfa+bu2aZSd+cNaCNP9IT9i5iXsiLNy20=";
    };
    dependencies = [];
    doCheck = false;
    meta.platforms = ["x86_64-linux"];
  };

  phonemizerFork = py.buildPythonPackage {
    pname = "phonemizer-fork";
    version = "3.3.2";
    pyproject = true;
    build-system = [py.hatchling];
    src = final.fetchPypi {
      pname = "phonemizer_fork";
      version = "3.3.2";
      hash = "sha256-EOFugn0EQ7CHBi4htV6AXACYnPE0Oy6B5zTK5fbAz2k=";
    };
    dependencies = with py; [attrs dlinfo joblib segments typing-extensions];
    doCheck = false;
    pythonImportsCheck = ["phonemizer"];
  };

  kokoroOnnx = py.buildPythonPackage {
    pname = "kokoro-onnx";
    version = "0.5.0";
    pyproject = true;
    build-system = [py.hatchling];
    src = final.fetchPypi {
      pname = "kokoro_onnx";
      version = "0.5.0";
      hash = "sha256-W+sV8IXigo7Y1JP3ksB5r4VxA6stzqoeESsXYFh6yWo=";
    };
    dependencies = with py; [espeakngLoader numpy onnxruntime phonemizerFork];
    doCheck = false;
    pythonImportsCheck = ["kokoro_onnx"];
  };

  piperTts = py.buildPythonPackage rec {
    pname = "piper-tts";
    version = "1.2.0";

    src = final.fetchFromGitHub {
      owner = "rhasspy";
      repo = "piper";
      tag = "2023.11.14-2";
      hash = "sha256-3ynWyNcdf1ffU3VoDqrEMrm5Jo5Zc5YJcVqwLreRCsI=";
    };

    sourceRoot = "${src.name}/src/python_run";
    format = "setuptools";

    dependencies = with py; [
      piper-phonemize
      onnxruntime
    ];

    doCheck = false;
    pythonImportsCheck = ["piper"];

    meta = {
      description = "A fast, local neural text to speech system";
      homepage = "https://github.com/rhasspy/piper";
      license = lib.licenses.mit;
    };
  };

  speachesSrc = final.fetchFromGitHub {
    owner = "speaches-ai";
    repo = "speaches";
    tag = "v0.8.3";
    hash = "sha256-rxO5xLKDpHLi8gT+TrefkL2204R2HChSLHYEHDgOOdk=";
  };
in {
  speaches = lib.makeOverridable ({
    withUi ? true,
    withDiarization ? false,
    withTelemetry ? false,
  }: let
    speachesLib = py.buildPythonPackage {
      pname = "speaches";
      version = "0.8.3";
      src = speachesSrc;
      pyproject = true;

      build-system = [py.hatchling];

      dependencies =
        (with py; [
          fastapi
          uvicorn
          pydantic
          pydantic-settings
          huggingface-hub
          python-multipart
          numpy
          sounddevice
          soundfile
          aiostream
          cachetools
          httpx
          httpx-ws
          aiortc
          openai
          faster-whisper
          ctranslate2
          kokoroOnnx
          piper-phonemize
          piperTts
        ])
        ++ lib.optionals withUi (with py; [gradio])
        ++ lib.optionals withTelemetry (with py; [
          opentelemetry-api
          opentelemetry-sdk
          opentelemetry-distro
          opentelemetry-exporter-otlp
          opentelemetry-instrumentation-asgi
          opentelemetry-instrumentation-fastapi
          opentelemetry-instrumentation-grpc
          opentelemetry-instrumentation-httpx
          opentelemetry-instrumentation-logging
          opentelemetry-instrumentation-requests
          opentelemetry-instrumentation-threading
          opentelemetry-instrumentation-urllib3
          opentelemetry-instrumentation-system-metrics
        ]);

      postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail 'version = "0.1.0"' 'version = "0.8.3"'

        substituteInPlace src/speaches/model_aliases.py \
          --replace-fail 'Path("model_aliases.json")' \
          'Path("${placeholder "out"}/share/speaches/model_aliases.json")'

        substituteInPlace src/speaches/main.py \
          --replace-fail 'StaticFiles(directory="realtime-console/dist"' \
          'StaticFiles(directory="${placeholder "out"}/share/speaches/realtime-console/dist"'
      '';

      pythonRelaxDeps = true;
      pythonRemoveDeps = [
        "kokoro-onnx"
        "aiortc"
        "openai"
        "piper-tts"
        "piper-phonemize"
      ];

      postInstall = ''
        datadir=$out/share/speaches
        mkdir -p $datadir/realtime-console
        cp model_aliases.json $datadir/
        cp -r realtime-console/dist $datadir/realtime-console/
      '';

      doCheck = false;
      pythonImportsCheck = ["speaches"];

      meta = {
        description = "OpenAI-compatible server for speech-to-text and text-to-speech";
        homepage = "https://github.com/speaches-ai/speaches";
        license = lib.licenses.mit;
        platforms = ["x86_64-linux"];
      };
    };
  in
    (final.python312.withPackages (_: [speachesLib])).overrideAttrs (old: {
      passthru = (old.passthru or {}) // {inherit speachesLib;};
      meta = (old.meta or {}) // {mainProgram = "uvicorn";};
    })) {};
}
