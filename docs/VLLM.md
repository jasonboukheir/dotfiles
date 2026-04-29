# vLLM on Brutus — references & TODOs

Target: Qwen3.6-35B-A3B 4-bit on Arc B70 Pro (BMG-G31, 32 GB) for concurrent agentic / retrieval workloads.

## Container images

- [intel/vllm tags](https://hub.docker.com/r/intel/vllm/tags) — current Intel-published images
- [intel/llm-scaler-vllm tags](https://hub.docker.com/r/intel/llm-scaler-vllm/tags) — Project Battlematrix fork
- [intel/llm-scaler vllm README](https://github.com/intel/llm-scaler/blob/main/vllm/README.md)
- [vLLM upstream `Dockerfile.xpu`](https://github.com/vllm-project/vllm/blob/main/docker/Dockerfile.xpu)
- [intel/ai-containers `vllm/0.10.2-xpu.md`](https://github.com/intel/ai-containers/blob/main/vllm/0.10.2-xpu.md) — older Intel image; persistent MoE GEMM, FP8 W8A16 / MXFP4 only

## XPU kernel status

- [vllm-xpu-kernels releases](https://github.com/vllm-project/vllm-xpu-kernels/releases) — INT4 W4A16 + MoE landed; AWQ/GPTQ INT4 GEMM still WIP
- [vllm#33214 — XPU kernel migration RFC](https://github.com/vllm-project/vllm/issues/33214)
- [vllm-omni#2570 — Q2 2026 XPU roadmap](https://github.com/vllm-project/vllm-omni/issues/2570) — FP8 KV cache, MoE INT4, AutoRound
- [vllm#39474 — GPTQ regression on XPU 0.19.0](https://github.com/vllm-project/vllm/issues/39474)
- [vllm#27408 — Battlemage SIGABRT on model inspection](https://github.com/vllm-project/vllm/issues/27408)
- [vllm#35638 — Best practices for 30B+ on Arc B580](https://github.com/vllm-project/vllm/issues/35638)

## Models

- [cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit](https://huggingface.co/cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit) — primary, compressed-tensors W4A16, **24.5 GB on disk** (5 safetensors). Despite the "AWQ" repo name, vLLM consumes it via `--quantization compressed-tensors`.
- [QuantTrio/Qwen3.6-35B-A3B-AWQ](https://huggingface.co/QuantTrio/Qwen3.6-35B-A3B-AWQ) — true AWQ, ~24 GB; revisit when XPU AWQ INT4 GEMM lands
- [unsloth/Qwen3.6-35B-A3B-GGUF](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF) — GGUF only (llama.cpp path, already deployed)
- [Qwen/Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) — official BF16 base
- [Qwen/Qwen3.5-35B-A3B](https://huggingface.co/Qwen/Qwen3.5-35B-A3B) — BF16 source for online INT4 fallback (llm-scaler `--quantization sym_int4`)
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

## Setups to try

Scouting runs raw `podman run …` on brutus. Each `[x]` here gets the working invocation pasted underneath for later translation into the nix flake.

- [ ] **A** — newest `intel/vllm:*-xpu` subtag past 0.17.0 + `cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit` + `--quantization compressed-tensors --gpu-memory-utilization 0.9 --max-model-len 32768 --reasoning-parser qwen3`
- [ ] **B** — `intel/llm-scaler-vllm:0.14.0-b8.1` (or newer) + same model/flags as A
- [ ] **B′** — `intel/llm-scaler-vllm` + `Qwen/Qwen3.5-35B-A3B` BF16 + `--quantization sym_int4` (online INT4 fallback)
- [ ] **C** — upstream vLLM `Dockerfile.xpu` @ 0.19.x build + same model/flags as A
- [ ] **D** — winning setup + `--kv-cache-dtype fp8`
- [ ] **E** — winning setup + `--max-num-seqs` ∈ {8,16,32} × `--max-num-batched-tokens` ∈ {4096,8192} sweep

## Tok/s expectations (Arc B70 Pro, single card)

- Single stream: ~10–14 tok/s for Qwen3.6-35B-A3B 4-bit (slower than llama.cpp SYCL's ~22 tok/s)
- 8-way concurrent: ~80–120 tok/s aggregate
- 50-way concurrent: 300–500 tok/s aggregate (KV-cache bound long before 50 at 32K context)

Stop condition for "good enough to deploy": ≥80 tok/s aggregate at 8-way concurrency, stable 32K context, no OOMs over a 30-minute soak.
