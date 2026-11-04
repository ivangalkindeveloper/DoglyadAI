"""Reproduce TensorRT-LLM's Gemma3 text preprocessing on CPU, without model weights."""

import json
from pathlib import Path

from transformers import AutoProcessor

root = Path("/survey")
snapshot = "/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots/290cda5eeccbee130f987c4ad74a59ae6f196408"
processor = AutoProcessor.from_pretrained(snapshot, local_files_only=True)
reference = {
    r["id"]: r["prompt_token_ids"]
    for line in (root / "vllm-4b-baseline/results.jsonl").read_text().splitlines()
    if (r := json.loads(line)).get("phase") == "quality"
}
usage = {
    r["id"]: r["usage"].get("prompt_tokens")
    for line in (root / "tensorrt-4b-flashinfer/results.jsonl").read_text().splitlines()
    if (r := json.loads(line)).get("phase") == "quality"
}
output = []
for case in json.loads((root / "cases.json").read_text()):
    if case["kind"] == "vision":
        continue
    prompt = processor.apply_chat_template(
        case["payload"]["messages"], tokenize=False, add_generation_prompt=True
    )
    # The inspected Gemma3InputProcessor calls AutoProcessor without overriding
    # add_special_tokens. Compare that exact call with the native template IDs.
    ids = processor(text=prompt, images=None, return_tensors="pt")["input_ids"][
        0
    ].tolist()
    expected = reference[case["id"]]
    output.append(
        {
            "id": case["id"],
            "cpu_reproduced_ids": ids,
            "first_ids": ids[:5],
            "vllm_first_ids": expected[:5],
            "bos_token_id": processor.tokenizer.bos_token_id,
            "same_after_removing_first_id": ids[1:] == expected,
            "reproduced_count_matches_server_usage": len(ids) == usage[case["id"]],
        }
    )
(root / "tensorrt-prompt-audit.json").write_text(json.dumps(output, indent=2) + "\n")
print(
    json.dumps(
        {
            "cases": len(output),
            "one_extra_bos": all(
                r["first_ids"][:2] == [r["bos_token_id"]] * 2
                and r["same_after_removing_first_id"]
                and r["reproduced_count_matches_server_usage"]
                for r in output
            ),
        }
    )
)
