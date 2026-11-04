"""BF16 Transformers reference: native prompts, XGrammar, and static batches."""

from __future__ import annotations

import base64
import copy
import hashlib
import importlib.metadata
import io
import json
import sys
import time

from PIL import Image
import torch
from transformers import AutoModelForImageTextToText, AutoProcessor, set_seed
from transformers.generation.streamers import BaseStreamer
import xgrammar as xgr
from xgrammar.contrib.hf import LogitsProcessor


class TokenTimer(BaseStreamer):
    def __init__(self) -> None:
        self.prompt = True
        self.first = None
        self.last = None

    def put(self, value: torch.Tensor) -> None:
        if self.prompt:
            self.prompt = False
            return
        now = time.perf_counter()
        self.first = self.first or now
        self.last = now

    def end(self) -> None:
        pass


def main() -> None:
    settings = json.load(sys.stdin)
    snapshot = settings["snapshot"]
    processor = AutoProcessor.from_pretrained(snapshot, local_files_only=True)
    tokenizer = processor.tokenizer
    started = time.perf_counter()
    model = AutoModelForImageTextToText.from_pretrained(
        snapshot,
        local_files_only=True,
        dtype=torch.bfloat16,
        device_map={"": "cuda:0"},
        attn_implementation="sdpa",
    ).eval()
    info = xgr.TokenizerInfo.from_huggingface(
        tokenizer, vocab_size=model.config.text_config.vocab_size
    )
    compiler = xgr.GrammarCompiler(info)
    print(
        json.dumps(
            {
                "event": "loaded",
                "seconds": time.perf_counter() - started,
                "versions": {
                    name: importlib.metadata.version(name)
                    for name in ("torch", "transformers", "xgrammar")
                },
                "dtype": str(model.dtype),
                "attention": model.config._attn_implementation,
            }
        ),
        flush=True,
    )

    def run(case: dict, phase: str, count: int = 1, wave: int = 0) -> dict:
        payload = case["payload"]
        messages = copy.deepcopy(payload["messages"])
        for message in messages:
            if isinstance(message["content"], list):
                for item in message["content"]:
                    if item.get("type") == "image_url":
                        value = item.pop("image_url")["url"]
                        item.update(
                            type="image",
                            image=Image.open(
                                io.BytesIO(base64.b64decode(value.split(",", 1)[1]))
                            ).convert("RGB"),
                        )
        inputs = processor.apply_chat_template(
            messages,
            tokenize=True,
            add_generation_prompt=True,
            return_dict=True,
            return_tensors="pt",
        ).to(model.device)
        for key, value in inputs.items():
            if torch.is_floating_point(value):
                inputs[key] = value.to(torch.bfloat16)
            if count > 1:
                inputs[key] = inputs[key].repeat(count, *([1] * (value.dim() - 1)))
        width = inputs["input_ids"].shape[1]
        logits = []
        if "schema" in case:
            grammar = compiler.compile_json_schema(
                json.dumps(case["schema"]), any_whitespace=False
            )
            lp = LogitsProcessor(grammar)
            lp.matchers = [
                xgr.GrammarMatcher(grammar, override_stop_tokens=[1, 106])
                for _ in range(count)
            ]
            lp.batch_size = count
            lp.token_bitmask = xgr.allocate_token_bitmask(
                count, model.config.text_config.vocab_size
            )
            logits = [lp]
        timer = TokenTimer()
        options = dict(
            max_new_tokens=payload["max_tokens"],
            max_time=300,
            do_sample=payload["temperature"] > 0,
            repetition_penalty=payload.get("repetition_penalty", 1.0),
            eos_token_id=[1, 106],
            pad_token_id=0,
            use_cache=True,
            logits_processor=logits,
            streamer=timer,
        )
        if phase.startswith("speed"):
            options["min_new_tokens"] = 256
        if options["do_sample"]:
            options.update(
                temperature=payload["temperature"],
                top_p=payload["top_p"],
                top_k=payload["top_k"],
            )
        set_seed(payload["seed"])
        torch.cuda.synchronize()
        start = time.perf_counter()
        with torch.inference_mode():
            response = model.generate(**inputs, **options)
        torch.cuda.synchronize()
        seconds = time.perf_counter() - start
        tokens = response[0, width:].tolist()
        text = tokenizer.decode(tokens, skip_special_tokens=True)
        first = timer.first - start if timer.first else None
        result = {
            "engine": "transformers",
            "id": case["id"],
            "kind": case["kind"],
            "phase": phase,
            "concurrency": count,
            "batching": "static",
            "wave": wave,
            "text": text,
            "output_sha256": hashlib.sha256(text.encode()).hexdigest(),
            "seconds": seconds,
            "first_token_seconds": first,
            "finish": "stop"
            if tokens[-1] in (1, 106)
            else "length"
            if len(tokens) == payload["max_tokens"]
            else "time",
            "usage": {"prompt_tokens": width, "completion_tokens": len(tokens)},
            "prompt_token_ids": inputs["input_ids"][0].tolist(),
            "output_token_ids": tokens,
            "decode_tokens_per_second": (len(tokens) - 1) / (seconds - first)
            if first is not None
            else None,
            "batch_tokens_per_second": count * len(tokens) / seconds,
        }
        print(json.dumps(result, ensure_ascii=False), flush=True)
        return result

    warm = copy.deepcopy(settings["cases"][0])
    warm["payload"]["max_tokens"] = 16
    run(warm, "warmup")
    for case in settings["cases"]:
        run(case, "quality")
    for count in settings.get("concurrencies", [1, 4]):
        for wave in range(-1, settings.get("repetitions", 5)):
            run(
                settings["performance"],
                "speed_warmup" if wave < 0 else "speed",
                count,
                wave,
            )


if __name__ == "__main__":
    main()
