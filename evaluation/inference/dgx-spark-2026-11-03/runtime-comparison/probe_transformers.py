"""Generate from the first token using the exact vLLM input token IDs and schema."""

from __future__ import annotations

import importlib.metadata
import json
from pathlib import Path
import sys
import time
import traceback

import torch
from transformers import AutoModelForImageTextToText, AutoTokenizer, set_seed
import xgrammar as xgr
from xgrammar.contrib.hf import LogitsProcessor


def main() -> None:
    data = json.load(sys.stdin)
    snapshot = Path(data["snapshot"])
    tokenizer = AutoTokenizer.from_pretrained(str(snapshot), local_files_only=True)
    started = time.monotonic()
    model = AutoModelForImageTextToText.from_pretrained(
        str(snapshot),
        local_files_only=True,
        dtype=torch.bfloat16,
        device_map={"": "cuda:0"},
        attn_implementation="sdpa",
    ).eval()
    print(
        json.dumps(
            {
                "event": "loaded",
                "seconds": time.monotonic() - started,
                "dtype": str(model.dtype),
                "attention": model.config._attn_implementation,
            }
        ),
        flush=True,
    )
    vocab_size = model.config.text_config.vocab_size
    token_info = xgr.TokenizerInfo.from_huggingface(tokenizer, vocab_size=vocab_size)
    compiler = xgr.GrammarCompiler(token_info)
    for case in data["cases"]:
        # Sampling RNGs differ across runtimes. Greedy comparisons isolate that variable.
        if "greedy" not in case["id"] and not case["id"].startswith("historical-"):
            continue
        payload = case["payload"]
        ids = torch.tensor([case["prompt_token_ids"]], device="cuda")
        native_ids = tokenizer.apply_chat_template(
            payload["messages"], tokenize=True, add_generation_prompt=True
        )
        if hasattr(native_ids, "keys"):
            native_ids = native_ids["input_ids"]
        if native_ids and isinstance(native_ids[0], list):
            native_ids = native_ids[0]
        assert native_ids == case["prompt_token_ids"], (
            "Native chat template differs from vLLM"
        )
        ctx = compiler.compile_json_schema(
            json.dumps(case["schema"]), any_whitespace=False
        )
        processor = LogitsProcessor(ctx)
        # Match vLLM 0.28: compiler uses tokenizer EOS, matcher uses generation-config stops.
        processor.matchers = [xgr.GrammarMatcher(ctx, override_stop_tokens=[1, 106])]
        processor.batch_size = 1
        processor.token_bitmask = xgr.allocate_token_bitmask(1, vocab_size)
        options = dict(
            input_ids=ids,
            attention_mask=torch.ones_like(ids),
            max_new_tokens=payload["max_tokens"],
            max_time=300,
            do_sample=payload["temperature"] > 0,
            repetition_penalty=payload["repetition_penalty"],
            eos_token_id=[1, 106],
            pad_token_id=0,
            logits_processor=[processor],
            use_cache=True,
        )
        if options["do_sample"]:
            options.update(temperature=payload["temperature"], top_p=1.0, top_k=0)
        set_seed(payload["seed"])
        started = time.monotonic()
        with torch.inference_mode():
            response = model.generate(**options)
        tokens = response[0, ids.shape[1] :].tolist()
        elapsed = time.monotonic() - started
        finish = (
            "stop"
            if tokens[-1] in (1, 106)
            else "length"
            if len(tokens) == payload["max_tokens"]
            else "time"
        )
        result = {
            "id": case["id"],
            "text": tokenizer.decode(tokens, skip_special_tokens=True),
            "finish": finish,
            "seconds": round(elapsed, 3),
            "output_token_ids": tokens,
            "prompt_token_ids": case["prompt_token_ids"],
            "native_prompt_matches": True,
            "usage": {"prompt_tokens": ids.shape[1], "completion_tokens": len(tokens)},
            "compiler_stop_ids": token_info.stop_token_ids,
            "matcher_stop_ids": [1, 106],
            "max_gpu_allocated_bytes": torch.cuda.max_memory_allocated(),
            "versions": {
                name: importlib.metadata.version(name)
                for name in ("xgrammar", "transformers", "torch")
            },
        }
        print(json.dumps(result, ensure_ascii=False), flush=True)
        del response, ids


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(
            json.dumps({"event": "probe_error", "traceback": traceback.format_exc()}),
            flush=True,
        )
        raise
