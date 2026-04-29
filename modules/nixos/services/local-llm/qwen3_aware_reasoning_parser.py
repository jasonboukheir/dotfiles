# Custom vLLM reasoning parser for Qwen3.6 chat-template prefill semantics.
#
# Qwen3.6's chat template prefills the assistant turn into the *prompt*:
#   enable_thinking=true  -> "<think>\n"             (model emits </think> only)
#   enable_thinking=false -> "<think>\n\n</think>\n\n" (model emits no tags)
#
# vLLM's reasoning parser only sees the *output* token stream, not the prompt,
# so for fast requests (enable_thinking=false) there is no </think> in the
# output. The bundled `deepseek_r1` parser interprets that as "still inside
# reasoning" and routes the entire response into reasoning_content.
#
# vLLM instantiates the reasoning parser per-request and forwards the merged
# chat_template_kwargs, so we can branch on enable_thinking at __init__ time:
#   - thinking_enabled=False  -> stream everything as content (no </think>)
#   - thinking_enabled=True   -> deepseek_r1 semantics (split on </think>)

from vllm.entrypoints.openai.protocol import DeltaMessage
from vllm.reasoning.abs_reasoning_parsers import ReasoningParserManager
from vllm.reasoning.basic_parsers import BaseThinkingReasoningParser


@ReasoningParserManager.register_module(["qwen3_aware"])
class Qwen3AwareReasoningParser(BaseThinkingReasoningParser):
    @property
    def start_token(self) -> str:
        return "<think>"

    @property
    def end_token(self) -> str:
        return "</think>"

    def __init__(self, tokenizer, *args, **kwargs):
        super().__init__(tokenizer, *args, **kwargs)
        chat_kwargs = kwargs.get("chat_template_kwargs") or {}
        self.thinking_enabled = chat_kwargs.get("enable_thinking", True)

    def extract_reasoning(self, model_output, request):
        if not self.thinking_enabled:
            return None, model_output

        parts = model_output.partition(self.start_token)
        model_output = parts[2] if parts[1] else parts[0]

        if self.end_token not in model_output:
            return model_output, None

        reasoning, _, content = model_output.partition(self.end_token)
        return reasoning, content or None

    def extract_reasoning_streaming(
        self,
        previous_text,
        current_text,
        delta_text,
        previous_token_ids,
        current_token_ids,
        delta_token_ids,
    ):
        if not self.thinking_enabled:
            return DeltaMessage(content=delta_text) if delta_text else None

        if len(delta_token_ids) == 1 and delta_token_ids[0] in (
            self.start_token_id,
            self.end_token_id,
        ):
            return None

        if self.start_token_id in delta_token_ids:
            start_idx = delta_text.find(self.start_token)
            if start_idx >= 0:
                delta_text = delta_text[start_idx + len(self.start_token):]

        if self.end_token_id in delta_token_ids:
            end_idx = delta_text.find(self.end_token)
            if end_idx >= 0:
                reasoning = delta_text[:end_idx]
                content = delta_text[end_idx + len(self.end_token):]
                if not reasoning and not content:
                    return None
                return DeltaMessage(
                    reasoning=reasoning if reasoning else None,
                    content=content if content else None,
                )
            return None

        if not delta_text:
            return None

        if self.end_token_id in previous_token_ids:
            return DeltaMessage(content=delta_text)

        return DeltaMessage(reasoning=delta_text)
