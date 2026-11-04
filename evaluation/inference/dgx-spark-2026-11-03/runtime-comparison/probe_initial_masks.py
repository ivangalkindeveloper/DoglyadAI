"""CPU-only probe of initial masks; takes one JSON schema on stdin."""

from __future__ import annotations

import json
from pathlib import Path
import sys

import llguidance
from transformers import AutoTokenizer
from vllm.v1.structured_output.backend_guidance import (
    llguidance_hf,
    llguidance_torch,
)
import xgrammar as xgr


def main() -> None:
    schema = json.load(sys.stdin)
    snapshot = Path(
        "/root/.cache/huggingface/hub/models--google--medgemma-4b-it/"
        "snapshots/290cda5eeccbee130f987c4ad74a59ae6f196408"
    )
    tokenizer = AutoTokenizer.from_pretrained(str(snapshot), local_files_only=True)
    info = xgr.TokenizerInfo.from_huggingface(tokenizer, vocab_size=262208)
    compiler = xgr.GrammarCompiler(info)
    rows = []
    for name, options in (
        ("xgrammar-compact", {"any_whitespace": False}),
        ("xgrammar-minified", {"any_whitespace": False, "separators": (",", ":")}),
        ("xgrammar-flexible", {"any_whitespace": True}),
    ):
        compiled = compiler.compile_json_schema(json.dumps(schema), **options)
        matcher = xgr.GrammarMatcher(compiled, override_stop_tokens=[1, 106])
        mask = xgr.allocate_token_bitmask(1, 262208)
        matcher.fill_next_token_bitmask(mask)
        rows.append(
            {
                "variant": name,
                "first_tokens": [
                    {
                        "id": token,
                        "token": tokenizer.convert_ids_to_tokens(token),
                        "mask_allowed": bool(
                            (int(mask[0, token // 32]) >> (token % 32)) & 1
                        ),
                        "accepted": xgr.GrammarMatcher(
                            compiled, override_stop_tokens=[1, 106]
                        ).accept_token(token),
                    }
                    for token in (236782, 14937)
                ],
            }
        )
    ll_tokenizer = llguidance_hf.from_tokenizer(tokenizer, 262208)
    grammar = llguidance.LLMatcher.grammar_from_json_schema(
        json.dumps(schema),
        defaults={"whitespace_flexible": False},
    )
    ll_matcher = llguidance.LLMatcher(ll_tokenizer, grammar)
    mask = llguidance_torch.allocate_token_bitmask(1, ll_tokenizer.vocab_size)
    llguidance_torch.fill_next_token_bitmask(ll_matcher, mask, 0)
    rows.append(
        {
            "variant": "guidance",
            "first_tokens": [
                {
                    "id": token,
                    "token": tokenizer.convert_ids_to_tokens(token),
                    "mask_allowed": bool(
                        (int(mask[0, token // 32]) >> (token % 32)) & 1
                    ),
                    "accepted": llguidance.LLMatcher(
                        ll_tokenizer, grammar
                    ).consume_tokens([token]),
                }
                for token in (236782, 14937)
            ],
        }
    )
    print(json.dumps(rows, ensure_ascii=False))


if __name__ == "__main__":
    main()
