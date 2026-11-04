"""Check the experimental prefill tile against FP32 attention before model startup."""

import json
from pathlib import Path

import torch

from lmdeploy.pytorch.kernels.cuda.flashattention import flash_attn_varlen_func

torch.manual_seed(42)
results = []
for length in (37, 260, 513):
    for window in (-1, 128):
        q = torch.randn(length, 8, 256, device="cuda", dtype=torch.bfloat16)
        k = torch.randn(length, 4, 256, device="cuda", dtype=torch.bfloat16)
        v = torch.randn_like(k)
        cu = torch.tensor([0, length], device="cuda", dtype=torch.int32)
        actual = flash_attn_varlen_func(
            q,
            k,
            v,
            cu,
            cu,
            max_seqlen_q=length,
            max_seqlen_k=length,
            causal=True,
            window_size=(window, window),
            kv_layout="shd",
        )
        q_ref = q.float().transpose(0, 1)
        k_ref = k.float().repeat_interleave(2, dim=1).transpose(0, 1)
        v_ref = v.float().repeat_interleave(2, dim=1).transpose(0, 1)
        index = torch.arange(length, device="cuda")
        mask = index[:, None] >= index[None, :]
        if window > 0:
            mask &= index[:, None] - index[None, :] <= window
        scores = (q_ref @ k_ref.transpose(-1, -2)) / 16
        scores.masked_fill_(~mask, -torch.inf)
        expected = (scores.softmax(-1) @ v_ref).transpose(0, 1)
        torch.testing.assert_close(actual.float(), expected, atol=0.025, rtol=0.025)
        results.append(
            {
                "length": length,
                "window": window,
                "max_absolute_error": (actual.float() - expected).abs().max().item(),
            }
        )
Path("/survey/lmdeploy-kernel-check.json").write_text(
    json.dumps(results, indent=2) + "\n"
)
print(json.dumps({"kernel_check": "passed", "cases": len(results)}), flush=True)
