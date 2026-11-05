"""Read cached model configuration and vLLM cache-capacity formulas without inference."""

import json
import subprocess

from run import NAMES, ROOT, save

CODE = r"""
import ast,hashlib,importlib.util,json,pathlib
root=pathlib.Path(importlib.util.find_spec('vllm').origin).parent
sources={}
for relative in ['v1/kv_cache_interface.py','v1/core/kv_cache_utils.py','config/vllm.py']:
 path=root/relative
 text=path.read_text()
 tree=ast.parse(text)
 snippets=[]
 for node in ast.walk(tree):
  if isinstance(node,ast.ClassDef) and node.name in ['SlidingWindowSpec','FullAttentionSpec']:
   for child in node.body:
    if isinstance(child,ast.FunctionDef) and child.name=='max_memory_usage_bytes':
     snippets.append({'name':node.name+'.'+child.name,'source':ast.get_source_segment(text,child)})
  if isinstance(node,ast.FunctionDef) and node.name in ['get_max_concurrency_for_kv_cache_config','max_admission_blocks_per_request','max_in_flight_tokens']:
   snippets.append({'name':node.name,'source':ast.get_source_segment(text,node)})
 sources[relative]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_header':text.splitlines()[:4],'snippets':snippets}
models={}
hub=pathlib.Path('/root/.cache/huggingface/hub')
for name in ['medgemma-4b-it','medgemma-1.5-4b-it','medgemma-27b-it']:
 files=list((hub/('models--google--'+name)/'snapshots').glob('*/config.json'))
 assert len(files)==1,(name,files)
 config=json.loads(files[0].read_text())
 models[name]={'revision':files[0].parent.name,'config_sha256':hashlib.sha256(files[0].read_bytes()).hexdigest(),'text_config':config.get('text_config',config)}
print(json.dumps({'model_configs':models,'vllm_sources':sources},ensure_ascii=False))
"""


def main() -> None:
    process = subprocess.run(
        ["docker", "exec", NAMES[0], "python3", "-c", CODE],
        capture_output=True,
        text=True,
        check=True,
        timeout=30,
    )
    result = json.loads(process.stdout)
    save(ROOT / "04-kv-cache/cache-accounting.json", result)
    print("Saved model attention configuration and vLLM cache-capacity formulas.")


if __name__ == "__main__":
    main()
