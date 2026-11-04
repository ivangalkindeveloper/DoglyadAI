"""Run each model in sequence without changing or restarting its container."""
from __future__ import annotations

from pathlib import Path
import json
import subprocess

D = Path(__file__).resolve().parent
for label, container in [
    ('4b', 'doglyad-dgx-vllm_medgemma_4b-1'),
    ('15-4b', 'doglyad-dgx-vllm_medgemma_15_4b-1'),
    ('27b', 'doglyad-dgx-vllm_medgemma_27b-1'),
]:
    manifest = D / f'{label}-manifest.json'
    variants = json.loads(manifest.read_text())
    remaining = []
    for variant in variants:
        path = D / f'{variant}-results.jsonl'
        if not path.exists():
            remaining.append(variant)
            continue
        cases = json.loads((D / f'{variant}-cases.json').read_text())
        rows = [r for line in path.read_text().splitlines() if (r := json.loads(line)).get('phase') == 'quality']
        assert len(rows) == len(cases), f'Archive incomplete diagnostic result first: {path}'
        assert {r['id'] for r in rows} == {c['id'] for c in cases}
        assert all(not r.get('error') and r.get('done') for r in rows)
        print(json.dumps({'event': 'preserved_complete', 'variant': variant, 'count': len(rows)}), flush=True)
    if not remaining:
        continue
    if remaining != variants:
        manifest = D / f'{label}-resume-manifest.json'
        with manifest.open('x') as output:
            json.dump(remaining, output)
    subprocess.run(['python3', '-u', str(D / 'run_experiment.py'), str(manifest), container], check=True)
