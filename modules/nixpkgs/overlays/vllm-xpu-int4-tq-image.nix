# vLLM XPU + INC INT4 MoE + TurboQuant KV cache, baked from `tq-hybrid-allow`
# at jasonboukheir/vllm@fcc0c8365.
#
# Stacked patches (all on /home/jasonbk/Projects/vllm tq-hybrid-allow):
#   38237e347  xpu_moe: XPUExpertsWNA16 wired to xpu_fused_moe(is_int4=True)
#   7d571957a  int_wna16: register WNA16MoEBackend.XPU
#   dd8eb8bb2  inc: INCXPUMoEMethod (W4A16 sym int4 MoE on XPU)
#   ecda6a6f8  inc: auto-claim vanilla GPTQ sym int4 on XPU
#   fcc0c8365  inc: parse GPTQModel `dynamic` field
#
# Image is published as a single squashed layer. Squashing was needed
# because the upstream-base image's /workspace/vllm/.git/hooks/*.sample
# files have shebangs pointing at /nix/store/<hash>-bash and
# /nix/store/<hash>-perl (artifact of git hooks being copied from a
# NixOS build host). Those samples are scrubbed in our Containerfile
# layer and `--squash-all` collapses everything into a single layer
# so the bytes never make it into the final image — keeps the FOD
# reference scan clean for `dockerTools.pullImage`.
#
# Validated 2026-04-30 against palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4 on a
# B70: 20.15 GiB model, 251k-token KV with `turboquant_k3v4_nc`,
# 28 tok/s single-stream eager, 555 tok/s 32-way agg. KL vs FP16 KV at
# 4096 ctx / top-2000: 0.0179 (top-1 100%, top-5 93%).
final: prev: {
  vllm-xpu-int4-tq-image = final.dockerTools.pullImage {
    imageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    imageDigest = "sha256:8c51da522fd8296cd31d18361e8a909139f06c4de1c406e185afed593183876d";
    # Replace with `lib.fakeHash` to learn the real hash on first build.
    hash = "sha256-/yOKKVROJQoLmR2JhrWgeuFw1GkkPOFoMj/5AoG0DuI=";
    finalImageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    finalImageTag = "fcc0c8365";
  };
}
