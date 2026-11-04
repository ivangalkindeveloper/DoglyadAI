"""Extend the single-factor vocabulary removal to the full frozen sample."""
from pathlib import Path
import copy
import json

D = Path(__file__).resolve().parent
sources = json.loads((D.parent / 'prompt-repair/expanded-baseline-cases.json').read_text())
rows = []
for source in sources:
    case = copy.deepcopy(source)
    lines = case['payload']['messages'][1]['content'].splitlines(keepends=True)
    assert sum(line.startswith('{"contextualStrings":') for line in lines) == 1
    case['payload']['messages'][1]['content'] = ''.join(
        line for line in lines if not line.startswith('{"contextualStrings":')
    )
    rows.append(case)
(D / 'expanded-no-vocabulary-cases.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
(D / 'expanded-manifest.json').write_text(json.dumps(['expanded-no-vocabulary']) + '\n')
print({'count': len(rows)})
