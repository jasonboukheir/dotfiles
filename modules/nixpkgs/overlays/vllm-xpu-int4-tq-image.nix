# vLLM XPU + INC INT4 MoE + TurboQuant KV cache + GDN graph-capture fix
# + GDN spec-decode (MTP/EAGLE) FLA fallback, baked from
# `tq-hybrid-allow-rebased` at jasonboukheir/vllm@b6a544b82.
#
# Stacked patches (all on /home/jasonbk/Projects/vllm tq-hybrid-allow-rebased):
#   38237e347  xpu_moe: XPUExpertsWNA16 wired to xpu_fused_moe(is_int4=True)
#   7d571957a  int_wna16: register WNA16MoEBackend.XPU
#   dd8eb8bb2  inc: INCXPUMoEMethod (W4A16 sym int4 MoE on XPU)
#   ecda6a6f8  inc: auto-claim vanilla GPTQ sym int4 on XPU
#   fcc0c8365  inc: parse GPTQModel `dynamic` field
#   ccd77bdf4  xpu: slice GDN inputs to num_actual_tokens (graph-capture fix)
#   b6a544b82  xpu: route GDN spec-decode batches through FLA Triton fallback
#
# b6a544b82 unblocks `--speculative-config '{"method":"mtp",
# "num_speculative_tokens":3}'` on Qwen3.6-A3B: the fused SYCL
# gdn_attention kernel has no spec-aware path, so the dispatcher
# (`_gdn_attention_core_xpu_impl`) detects `spec_sequence_masks` and
# defers to the same FLA Triton flow that forward_cuda uses. Non-spec
# batches keep the SYCL fast path. The runtime branch lives inside the
# custom op (opaque to torch.compile via direct_register_custom_op) so
# graph capture still works.
#
# Validated 2026-05-06 against palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4 on
# B70 with MTP-K3: 200 OK on 12/12 prompts, per-position acceptance
# 85.6% / 71.0% / 58.6% (canonical MTP shape), 1.13-1.49x speedup vs
# SYCL no-spec baseline depending on workload. Run-vs-run determinism:
# 12/12 byte-equal.
final: prev: {
  vllm-xpu-int4-tq-image = final.dockerTools.pullImage {
    imageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    imageDigest = "sha256:81094bcfc55b28f2b43e9fcf3e91a26a47feadeeaba91007156049889e0b9b64";
    # Replace with `lib.fakeHash` to learn the real hash on first build.
    hash = "sha256-bPmov/XHkiSNJskfxiXcPII98ElfCmLmvAqm/0lU0ms=";
    finalImageName = "ghcr.io/jasonboukheir/vllm-xpu-int4-tq";
    finalImageTag = "spec-fix-b6a544b82";
  };
}
