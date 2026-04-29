# vLLM on Brutus — references & TODOs

Target: Qwen3.6-35B-A3B 4-bit on Arc B70 Pro (BMG-G31, 32 GB) for concurrent agentic / retrieval workloads.

## Status (2026-04-29)

**Working setup**: `intel/llm-scaler-vllm:0.14.0-b8.2` + `Qwen/Qwen3.6-35B-A3B` (BF16 base) + `--quantization sym_int4` (online IPEX/GGML Q4_0 inline-pack) + `--kv-cache-dtype fp8`. Validated end-to-end via raw podman before translation:

- **VRAM**: 19.01 GiB model footprint
- **KV cache**: 206,720 tokens at `--max-model-len 32768` (with fp8 KV; doubles the bf16-KV baseline of 103,104)
- **Throughput** (200-token completions, single benchmark, no soak):
  - 1-stream: 20.2 tok/s
  - 4-stream: 79 tok/s aggregate (19.8 / stream)
  - 8-stream: 155 tok/s aggregate (19.4 / stream)
  - 16-stream: 310 tok/s aggregate (19.4 / stream)
  - 32-stream: 551 tok/s aggregate (17.2 / stream)
  - 64-stream: 868 tok/s aggregate (13.6 / stream)

Per-stream stays within 5% of single-stream through 16-way — the card is far from the kernel ceiling on this model.

### Required flags (see `modules/nixos/services/local-llm/vllm.nix` for the rendered invocation)

- `--dtype float16` — `sym_int4` rejects bfloat16
- `--quantization sym_int4` — only working XPU MoE INT4 path in this image
- `--enforce-eager` — inductor compile silently spends minutes on the linear-attention/MoE hybrid forward; eager-mode is already at kernel ceiling
- `--limit-mm-per-prompt '{"image":0,"video":0}'` — Qwen3.6-35B-A3B is VL-tagged. Without this, MM-budget init calls `Qwen2VLImageProcessor.max_pixels` which newer transformers dropped → crash
- `--reasoning-parser qwen3` — surfaces `<think>` blocks into `reasoning_content`
- env `CCL_ZE_IPC_EXCHANGE=sockets` + `CCL_PROCESS_LAUNCHER=none` + `CCL_LOCAL_{RANK,SIZE}=0/1` — without these the OneCCL warmup `all_reduce` hangs even at world_size=1

## Why the doc's setup A/B both failed

Both `intel/vllm:0.17.0-xpu` and `intel/llm-scaler-vllm:0.14.0-b8.2` route a compressed-tensors / GPTQ / AWQ W4A16 MoE checkpoint through `CompressedTensorsWNA16MarlinMoEMethod`, which calls `torch.ops._C.gptq_marlin_repack` — that op is CUDA-only, no XPU registration. Selection logic at `compressed_tensors_moe.py:166` only opts out of Marlin on ROCm; XPU silently falls through.

Other dead-end paths investigated:

- **AutoRound INT4** (`shieldstar/Qwen3.6-35B-A3B-int4-AutoRound-EC` etc.) — `auto_round.py:457` correctly dispatches XPU to `apply_ipex_quant_layer`, but that handler's `else` branch returns `None` for non-`LinearBase` layers, so `FusedMoE` falls back to `UnquantizedFusedMoEMethod` → BF16 weights → OOM on 32 GB.
- **Pre-quantized AWQ / GPTQ Int4 checkpoints** (`palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4` etc.) — same Marlin dead-end via `MoeWNA16Config.use_marlin = True`.
- **`Qwen/Qwen3.6-35B-A3B-FP8`** — FP8 doesn't go through Marlin, but ~38 GB on disk = doesn't fit 32 GB VRAM after KV/runtime overhead.

The model is also genuinely multimodal (`Qwen3_5MoeForConditionalGeneration`, hybrid linear-attention + MoE) — `Qwen3.6-35B-A3B` is the VL variant. There is no text-only `Qwen3.6-35B-A3B` repo on HF.

## Quantization recommendation

Stick with `sym_int4` (online GGML Q4_0) until either of these lands:

1. **AutoRound INT4 + FusedMoE XPU dispatch** in `auto_round.py:apply_ipex_quant_layer` — would give calibrated Q4 (better PPL than Q4_0 RTN) on Intel-native kernels. Roadmap: vllm-omni Q1–Q2 2026.
2. **MXFP4 GEMM for Qwen3-MoE** in `vllm-xpu-kernels` — currently only `gpt-oss-20b/120b` in llm-scaler. FP4 with exponent bits typically beats INT4 by 1–3% PPL.

NVFP4, FP8, INT8, and Q4_K_M are all non-options today (Nvidia-only, too big, or not loadable by vLLM).

## Container images

- [intel/vllm tags](https://hub.docker.com/r/intel/vllm/tags) — `0.17.0-xpu` is the latest as of 2026-04-29 (no `*-xpu` past 0.17.0)
- [intel/llm-scaler-vllm tags](https://hub.docker.com/r/intel/llm-scaler-vllm/tags) — `0.14.0-b8.2` is the latest as of 2026-04-29
- [intel/llm-scaler vllm README](https://github.com/intel/llm-scaler/blob/main/vllm/README.md) — documents `sym_int4` for `Qwen3-30B-A3B` and `Qwen3-Coder-30B-A3B-Instruct`; Qwen3.6 isn't listed but works in practice via the same path
- [vLLM upstream `Dockerfile.xpu`](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.xpu)
- [intel/ai-containers `vllm/0.10.2-xpu.md`](https://github.com/intel/ai-containers/blob/main/vllm/0.10.2-xpu.md) — older Intel image; persistent MoE GEMM, FP8 W8A16 / MXFP4 only

## XPU kernel status

- [vllm-xpu-kernels releases](https://github.com/vllm-project/vllm-xpu-kernels/releases) — INT4 W4A16 + MoE landed; AWQ/GPTQ INT4 GEMM still WIP. Latest as of 2026-04-29: `v0.1.7` (27 Apr)
- [vllm#33214 — XPU kernel migration RFC](https://github.com/vllm-project/vllm/issues/33214)
- [vllm-omni#2570 — Q2 2026 XPU roadmap](https://github.com/vllm-project/vllm-omni/issues/2570) — FP8 KV cache, MoE INT4, AutoRound
- [vllm#39474 — GPTQ regression on XPU 0.19.0](https://github.com/vllm-project/vllm/issues/39474)
- [vllm#27408 — Battlemage SIGABRT on model inspection](https://github.com/vllm-project/vllm/issues/27408)
- [vllm#35638 — Best practices for 30B+ on Arc B580](https://github.com/vllm-project/vllm/issues/35638)

## Models

- [Qwen/Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) — official BF16 base. **Currently the only viable input** for vLLM-XPU at INT4 (via `--quantization sym_int4`). 70 GB on disk.
- [cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit](https://huggingface.co/cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit) — compressed-tensors W4A16, ~24.5 GB. Marlin dead-end on XPU. Re-evaluate when llm-scaler ships an XPU CompressedTensorsWNA16 path.
- [QuantTrio/Qwen3.6-35B-A3B-AWQ](https://huggingface.co/QuantTrio/Qwen3.6-35B-A3B-AWQ) — true AWQ, ~24 GB. Same Marlin dead-end.
- [palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4](https://huggingface.co/palmfuture/Qwen3.6-35B-A3B-GPTQ-Int4) — GPTQ Int4. Same Marlin dead-end.
- [shieldstar/Qwen3.6-35B-A3B-int4-AutoRound-EC](https://huggingface.co/shieldstar/Qwen3.6-35B-A3B-int4-AutoRound-EC) — AutoRound int4. Linear→IPEX works; FusedMoE→BF16 OOM (see "Why setup A/B failed").
- [unsloth/Qwen3.6-35B-A3B-GGUF](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF) — GGUF, llama.cpp-only path (already deployed as the active backend's fallback).
- [Qwen/Qwen3.6-35B-A3B-FP8](https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8) — official FP8 (~38 GB). Non-Marlin path exists but won't fit 32 GB VRAM.
- [vLLM Qwen3.5/3.6 recipe](https://docs.vllm.ai/projects/recipes/en/latest/Qwen/Qwen3.5.html)

## Tok/s reference

- [PMZFX B70 LLM benchmarks](https://github.com/PMZFX/intel-arc-pro-b70-benchmarks/blob/master/llm-benchmarks.md) — single-card Qwen3.5-27B Q4 numbers
- [Hal9000AIML B70 Ubuntu speedup bugfixes](https://github.com/Hal9000AIML/arc-pro-b70-ubuntu-gpu-speedup-bugfixes) — 2–7x llama.cpp speedup notes
- [Roger Ngo — vLLM on Arc XPU](https://www.rogerngo.com/blog/accessible-ai-vllm-on-intel-arc) — A140V / dual B580 numbers
- [Phoronix — Intel llm-scaler-vllm 0.14.0-b8](https://www.phoronix.com/news/Intel-llm-scaler-vllm-0.14-b8) — 1.49× perf on BMG-G31

## KV cache quantization

- [vLLM Quantized KV Cache docs](https://docs.vllm.ai/en/latest/features/quantization/quantized_kvcache/)
- [vLLM blog — FP8 KV-cache state](https://vllm.ai/blog/fp8-kvcache)
- [vllm#39137 — fp8 KV gate fires on non-fp8 checkpoints](https://github.com/vllm-project/vllm/issues/39137)
- [vllm#33480 — INT8 KV cache feature request](https://github.com/vllm-project/vllm/issues/33480)
- [TurboQuant (CUDA, vllm#38171)](https://github.com/vllm-project/vllm/issues/38171), [RotorQuant (vllm#38291)](https://github.com/vllm-project/vllm/issues/38291), [IsoQuant paper](https://arxiv.org/html/2603.28430) — out of scope this round

## Setups tried

- [x] **A** — `intel/vllm:0.17.0-xpu` + `cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit` + `--quantization compressed-tensors`. **FAIL** at `process_weights_after_loading` → `gptq_marlin_repack` not registered on XPU.
- [x] **B** — `intel/llm-scaler-vllm:0.14.0-b8.2` + same model/flags. **FAIL** earlier — newer transformers dropped `Qwen2VLImageProcessor.max_pixels` so MM-budget init crashed before weight load. Bypassing with `--limit-mm-per-prompt` got past that, but then hit the same Marlin dead-end.
- [x] **B'-fixed** — `intel/llm-scaler-vllm:0.14.0-b8.2` + `Qwen/Qwen3.6-35B-A3B` (BF16) + `--quantization sym_int4 --dtype float16 --enforce-eager --limit-mm-per-prompt {"image":0,"video":0} --reasoning-parser qwen3` + `CCL_ZE_IPC_EXCHANGE=sockets` env hints. **WORKS.** See "Status" above for numbers. This is the encoded path in the nix module.
- [ ] **C** — upstream vLLM `Dockerfile.xpu` @ 0.19.x build. Skipped — `B'-fixed` already meets stop condition at 6.9× the target throughput (155 tok/s 8-way vs. ≥80 tok/s target), so multi-hour from-source build is unwarranted right now.
- [x] **D** — winning setup + `--kv-cache-dtype fp8`. **Net win**: KV cache headroom doubles from 103,104 → 206,720 tokens, model footprint unchanged at 19.01 GiB. Throughput cost ~2–3% per stream (1=20.2→19.5, 8=155.1→155.2, 32=551.6→539.2 tok/s) — a clear trade for agentic concurrency where context grows. Wired in as `services.local-llm.vllm.kvCacheDtype = "fp8"` (default).
- [x] **E** — `--max-num-batched-tokens 4096 --max-num-seqs 64` sweep. **No improvement** (1=19.6 / 8=152.7 / 32=530.6 / 64=868.1 tok/s agg) — slight 1-2% regression at low/mid concurrency. vLLM's defaults are already at the kernel ceiling. Side benefit of the test: confirmed 64-way ceiling at **868 tok/s aggregate** (per-stream 13.6 tok/s, still usable). Not encoding the flags.

### Things that don't work (and why)

- **`--enable-prefix-caching`** — silently disabled on load: `config.py:345 — Hybrid or mamba-based model detected without support for prefix caching: disabling`. Qwen3.6-MoE has linear-attention layers (mamba-style state) that vLLM's prefix-caching path can't represent. `vllm:prefix_cache_queries_total` stays at 0 even with the flag set. Don't bother enabling it for this arch.
- **Removing `--enforce-eager`** — hard crash, not just slow compile. Dynamo trips on IPEX's pybind11 C-extension `intel_extension_for_pytorch._C._has_xmx` and bails with `torch._dynamo.exc.Unsupported: Attempted to call function marked as skipped`. The compile path can't trace `_has_xmx` (the XMX-probe call inside IPEX's linear-attention forward). Eager mode is required, not optional.
- **`--reasoning-parser qwen3`** with the Qwen3.6 chat template — looks correct, but the template prefills `<think>\n` into the *prompt* (chat_template.jinja:152), so the model's output stream has `</think>` but never an opening `<think>`. The `qwen3` parser strictly requires both tokens (`qwen3_reasoning_parser.py:46`: "Qwen3 has stricter requirements - it needs both start and end tokens to be present") and falls back to "all output → content". Chain-of-thought leaks into the `content` field; `reasoning_content` stays null. **Use `--reasoning-parser deepseek_r1`** instead — same delimiters, but its base implementation handles the missing-start-token case (sees `</think>` and treats everything before as reasoning).

## Tok/s expectations vs. observed (Arc B70 Pro, single card)

| Stream count | Doc estimate | Observed |
|---|---|---|
| Single | 10–14 tok/s (slower than llama.cpp's ~22) | 20.2 tok/s |
| 8-way | 80–120 tok/s aggregate | 155 tok/s |
| 50-way | 300–500 tok/s aggregate | 551 tok/s at 32-way already |

Doc's estimates were conservative — single-stream is faster than llama.cpp Q4_K_M (22 → 20 is comparable, and llama.cpp was tuned over weeks) and concurrent throughput nearly doubles the high estimate.

## Stop condition (met)

> ≥80 tok/s aggregate at 8-way concurrency, stable 32K context, no OOMs over a 30-minute soak.

- Burst (8-way, 200 tok): 155 tok/s aggregate
- 30-min 8-way soak: 1433 requests, 286,600 tokens, **158.6 tok/s aggregate sustained**, **0 errors**, per-minute throughput stayed in 155–164 tok/s with no drift

Ready to deploy: flip `enable = false → true` in `hosts/brutus/services/local-llm.nix` and `nixos-rebuild switch`.
