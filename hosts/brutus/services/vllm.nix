{
  lib,
  config,
  ...
}: let
  cfg = config.services.vllm;
  port = config.sunnycareboo.ports.values.vllm;
in {
  sunnycareboo.ports.allocate.vllm = lib.mkIf cfg.enable 8000;
  services.vllm = {
    enable = false;
    port = port;
    model = "palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4";
    maxModelLen = 8192;
    extraArgs = ["--quantization" "gptq" "--gpu-memory-utilization" "0.9"];
  };

  sunnycareboo.services.vllm = lib.mkIf cfg.enable {
    enable = true;
    proxyPass = "http://127.0.0.1:${toString port}";
  };
}
