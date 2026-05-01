# vLLM XPU + INC INT4 MoE + TurboQuant KV cache + GDN graph-capture fix,
# baked from `tq-hybrid-allow-rebased` at jasonboukheir/vllm@ccd77bdf4.
#
# Stacked patches (all on /home/jasonbk/Projects/vllm tq-hybrid-allow-rebased):
#   38237e347  xpu_moe: XPUExpertsWNA16 wired to xpu_fused_moe(is_int4=True)
#   7d571957a  int_wna16: register WNA16MoEBackend.XPU
#   dd8eb8bb2  inc: INCXPUMoEMethod (W4A16 sym int4 MoE on XPU)
#   ecda6a6f8  inc: auto-claim vanilla GPTQ sym int4 on XPU
#   fcc0c8365  inc: parse GPTQModel `dynamic` field
#   ccd77bdf4  xpu: slice GDN inputs to num_actual_tokens (graph-capture fix)
#
# The GDN fix unblocks `enforceEager = false` + `enableXpuGraph = true`
# + `cudagraphCaptureSizes = [1 4]` for hybrid models (Qwen3.6-A3B has
# 10 full-attn + 30 GDN linear-attn layers); single-stream lifts from
# ~20 tok/s to ~65 tok/s.
#
# Validated 2026-04-30 against palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4 on a
# B70: 20.15 GiB model, 251k-token KV with `turboquant_k3v4_nc`,
# 28 tok/s single-stream eager, 555 tok/s 32-way agg. KL vs FP16 KV at
# 4096 ctx / top-2000: 0.0179 (top-1 100%, top-5 93%).
final: prev: {
  vllm-xpu-int4-tq-image = final.dockerTools.pullImage {
    imageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    imageDigest = "sha256:382b7be65fb2afde354d6e5a3e1086e806614cafd921d9bfef15bea128d97fc8";
    # Replace with `lib.fakeHash` to learn the real hash on first build.
    hash = "sha256-i8lrFdPV0V5gj+NkuSJ8CpaX5Bx1snQQ1usPpPuGctY=";
    finalImageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    finalImageTag = "gdn-fix-ccd77bdf4";
  };
}
