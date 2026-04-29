final: prev: {
  intel-llm-scaler-vllm-image = final.dockerTools.pullImage {
    imageName = "intel/llm-scaler-vllm";
    imageDigest = "sha256:b7bd35d454313e5a8e3b2314e3c8450033674c200a2d3870a6fd5233d1913194";
    hash = "sha256-x/B74hs/+SN7TxR+Zs7jYQli9OjRiR1MQZPfLztWRdU=";
    finalImageName = "intel/llm-scaler-vllm";
    finalImageTag = "0.14.0-b8.2";
  };
}
