final: prev:
# TODO: drop this overlay once LiteLLM forwards `delta.reasoning` (vLLM 0.20+
# field name) instead of dropping reasoning-only chunks in
# `is_chunk_non_empty`. Tracked upstream; multiple PRs open but unmerged.
# https://github.com/BerriAI/litellm/issues/20246
# https://github.com/BerriAI/litellm/pull/24020
let
  patchLiteLLM = py:
    py.override {
      packageOverrides = pyFinal: pyPrev: {
        litellm = pyPrev.litellm.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./litellm-streaming-reasoning.patch];
        });
      };
    };
in {
  python313 = patchLiteLLM prev.python313;
  python312 = patchLiteLLM prev.python312;
}
