"""Run full structured generations with explicit model and sampling controls."""

from __future__ import annotations

import importlib.metadata
import json
import sys
import time
import traceback

import torch
from transformers import (
    AutoModelForCausalLM,
    AutoModelForImageTextToText,
    AutoTokenizer,
    set_seed,
)
import xgrammar as xgr
from xgrammar.contrib.hf import LogitsProcessor


def main() -> None:
    data = json.load(sys.stdin)
    tokenizer = AutoTokenizer.from_pretrained(data["snapshot"], local_files_only=True)
    model_type = (
        AutoModelForImageTextToText
        if data["family"] == "medgemma"
        else AutoModelForCausalLM
    )
    started = time.monotonic()
    model = model_type.from_pretrained(
        data["snapshot"],
        local_files_only=True,
        dtype=torch.bfloat16,
        device_map={"": "cuda:0"},
        attn_implementation="sdpa",
    ).eval()
    config = getattr(model.config, "text_config", model.config)
    stops = model.generation_config.eos_token_id
    if isinstance(stops, int):
        stops = [stops]
    info = xgr.TokenizerInfo.from_huggingface(tokenizer, vocab_size=config.vocab_size)
    compiler = xgr.GrammarCompiler(info)
    print(
        json.dumps(
            {
                "event": "loaded",
                "seconds": time.monotonic() - started,
                "model_class": type(model).__name__,
                "model_parameters": model.num_parameters(),
                "eos_token_ids": stops,
                "compiler_stop_ids": info.stop_token_ids,
            }
        ),
        flush=True,
    )
    for case in data["cases"]:
        payload = case["payload"]
        native_ids = tokenizer.apply_chat_template(
            payload["messages"], tokenize=True, add_generation_prompt=True
        )
        if hasattr(native_ids, "keys"):
            native_ids = native_ids["input_ids"]
        if native_ids and isinstance(native_ids[0], list):
            native_ids = native_ids[0]
        assert native_ids == case["prompt_token_ids"], "Input tokens differ from vLLM"
        ids = torch.tensor([native_ids], device="cuda")
        ctx = compiler.compile_json_schema(
            json.dumps(case["schema"]), any_whitespace=False
        )
        processor = LogitsProcessor(ctx)
        processor.matchers = [xgr.GrammarMatcher(ctx, override_stop_tokens=stops)]
        processor.batch_size = 1
        processor.token_bitmask = xgr.allocate_token_bitmask(1, config.vocab_size)
        options = dict(
            input_ids=ids,
            attention_mask=torch.ones_like(ids),
            max_new_tokens=payload["max_tokens"],
            max_time=300,
            do_sample=payload["temperature"] > 0,
            repetition_penalty=payload["repetition_penalty"],
            eos_token_id=stops,
            pad_token_id=model.generation_config.pad_token_id,
            logits_processor=[processor],
            use_cache=True,
        )
        options.update(data.get("sampling_overrides", {}))
        if options["do_sample"]:
            options.update(
                temperature=payload["temperature"],
                top_p=payload["top_p"],
                top_k=max(0, payload["top_k"]),
            )
        set_seed(payload["seed"])
        started = time.monotonic()
        result = {
            "id": case["id"],
            "model": case["model"],
            "prompt_token_ids": native_ids,
            "native_prompt_matches": True,
            "sampling_overrides": data.get("sampling_overrides", {}),
            "versions": {
                name: importlib.metadata.version(name)
                for name in ("xgrammar", "transformers", "torch")
            },
        }
        try:
            with torch.inference_mode():
                response = model.generate(**options)
            tokens = response[0, ids.shape[1] :].tolist()
            finish = (
                "stop"
                if tokens[-1] in stops
                else "length"
                if len(tokens) == payload["max_tokens"]
                else "time"
            )
            result.update(
                text=tokenizer.decode(tokens, skip_special_tokens=True),
                finish=finish,
                output_token_ids=tokens,
                usage={
                    "prompt_tokens": len(native_ids),
                    "completion_tokens": len(tokens),
                },
            )
            del response
        except Exception as error:
            result.update(
                text="",
                finish="error",
                error=type(error).__name__,
                traceback=traceback.format_exc(),
            )
        result.update(
            seconds=round(time.monotonic() - started, 3),
            max_gpu_allocated_bytes=torch.cuda.max_memory_allocated(),
        )
        print(json.dumps(result, ensure_ascii=False), flush=True)
        del ids, processor, ctx


if __name__ == "__main__":
    main()
