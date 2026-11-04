"""Change only the count of one exact recorded token block in a failed prefix."""
import json
import math
from pathlib import Path
import sys
import urllib.request

import xgrammar as xgr
from transformers import AutoTokenizer

snapshot = Path('/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots/290cda5eeccbee130f987c4ad74a59ae6f196408')
tokenizer = AutoTokenizer.from_pretrained(str(snapshot), local_files_only=True)
entry = next(x for x in json.load(sys.stdin) if x['case']['id'] == 'conflict-sample-42')
case, trace = entry['case'], entry['trace']
ids = trace['output_token_ids']
text = tokenizer.decode(ids, skip_special_tokens=False, clean_up_tokenization_spaces=False)
block = (' Также, в описании указано, что в правой доле выявлено очаговое образование.'
         ' Это противоречит описанию структуры щитовидной железы.'
         ' Необходимо уточнить, является ли очаговое образование, или это просто описание структуры щитовидной железы.')
start = text.index(block)
end = start + len(block)
boundaries = {}
for i in range(len(ids) + 1):
    decoded = tokenizer.decode(ids[:i], skip_special_tokens=False, clean_up_tokenization_spaces=False)
    if len(decoded) in (start, end):
        boundaries[len(decoded)] = i
assert set(boundaries) == {start, end}
base, cycle = ids[:boundaries[start]], ids[boundaries[start]:boundaries[end]]
assert tokenizer.decode(base + cycle, skip_special_tokens=False, clean_up_tokenization_spaces=False) == text[:end]
targets = {1, 106, 107, ids[boundaries[end]]}
for candidate in ['"}', '"', ' Также', ' Необходимо', ' Если']:
    targets.add(tokenizer.encode(candidate, add_special_tokens=False)[0])
info = xgr.TokenizerInfo.from_huggingface(tokenizer, vocab_size=262208)
grammar = xgr.GrammarCompiler(info).compile_json_schema(json.dumps(case['schema']), any_whitespace=False)
for copies in [0, 1, 2, 4, 8, 16]:
    prefix = base + cycle * copies
    matcher = xgr.GrammarMatcher(grammar, override_stop_tokens=[1, 106])
    assert all(matcher.accept_token(token) for token in prefix)
    mask = xgr.allocate_token_bitmask(1, 262208)
    matcher.fill_next_token_bitmask(mask)
    body = {
        'model': case['model'], 'prompt': trace['prompt_token_ids'] + prefix,
        'add_special_tokens': False, 'max_tokens': 1, 'temperature': 0,
        'repetition_penalty': 1.0, 'skip_special_tokens': False,
        'return_tokens_as_token_ids': True, 'logprobs': len(targets),
        'logprob_token_ids': sorted(targets),
    }
    request = urllib.request.Request('http://127.0.0.1:8000/v1/completions', data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=120) as response:
        result = json.load(response)
    values = []
    for key, value in result['choices'][0]['logprobs']['top_logprobs'][0].items():
        token = int(key.split(':')[-1])
        values.append({'id': token, 'text': tokenizer.decode([token]), 'p': math.exp(value), 'allowed': bool((int(mask[0, token // 32]) >> (token % 32)) & 1)})
    print(json.dumps({'copies': copies, 'case': case['id'], 'base_token_ids': base, 'cycle_token_ids': cycle, 'cycle_text': block, 'prefix_length': len(prefix), 'values': sorted(values, key=lambda x: -x['p']), 'chosen': result['choices'][0]['text']}, ensure_ascii=False), flush=True)
