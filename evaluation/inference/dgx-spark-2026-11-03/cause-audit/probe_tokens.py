"""Inspect exact recorded token prefixes without loading a second model."""
from __future__ import annotations
import json
import math
from pathlib import Path
import re
import sys
import urllib.request
import xgrammar as xgr
from transformers import AutoTokenizer

SNAPSHOT=Path('/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots/290cda5eeccbee130f987c4ad74a59ae6f196408')
tokenizer=AutoTokenizer.from_pretrained(str(SNAPSHOT),local_files_only=True)
info=xgr.TokenizerInfo.from_huggingface(tokenizer,vocab_size=262208)
compiler=xgr.GrammarCompiler(info)

def post(payload):
 req=urllib.request.Request('http://127.0.0.1:8000/v1/completions',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=120) as r:return json.load(r)
 except urllib.error.HTTPError as e:raise RuntimeError(e.read().decode()) from e

def probability_rows(response,mask):
 result=[]
 for key,value in response['choices'][0]['logprobs']['top_logprobs'][0].items():
  tid=int(key.split(':')[-1]);result.append({'id':tid,'token':tokenizer.decode([tid],skip_special_tokens=False),'p':math.exp(value),'allowed':bool((int(mask[0,tid//32])>>(tid%32))&1)})
 return sorted(result,key=lambda x:-x['p'])

for entry in json.load(sys.stdin):
 case=entry['case'];trace=entry['trace'];ids=trace['output_token_ids'];prompt=trace['prompt_token_ids']
 decoded=tokenizer.decode(ids,skip_special_tokens=True,clean_up_tokenization_spaces=False)
 assert decoded==trace['text'],case['id']
 # Verify the template used by the actual server matches the model's own template.
 native=tokenizer.apply_chat_template(case['payload']['messages'],tokenize=True,add_generation_prompt=True,return_dict=True)['input_ids']
 assert native==prompt,(case['id'],'template mismatch')
 start=decoded.index('"descriptionRemarks":')
 boundaries=[m.end()+start for m in re.finditer(r'[.!?](?=\s)',decoded[start:])]
 points={}
 if boundaries:
  for n in [0,1,2,3,4,7,11,19]:
   if n<len(boundaries):
    char=boundaries[n]
    for i in range(1,len(ids)+1):
     prefix=tokenizer.decode(ids[:i],skip_special_tokens=False,clean_up_tokenization_spaces=False)
     if len(prefix)>=char:
      points[i]=n;break
 else:
  points[len(ids)-1]=-1
 matcher=xgr.GrammarMatcher(compiler.compile_json_schema(json.dumps(case['schema']),any_whitespace=False),override_stop_tokens=[1,106])
 pos=0
 for index,n in sorted(points.items()):
  while pos<index:
   assert matcher.accept_token(ids[pos]),(case['id'],pos,ids[pos]);pos+=1
  mask=xgr.allocate_token_bitmask(1,262208);matcher.fill_next_token_bitmask(mask)
  request={'model':case['model'],'prompt':prompt+ids[:index],'add_special_tokens':False,'max_tokens':1,'temperature':0,'repetition_penalty':1.0,'skip_special_tokens':False,'return_tokens_as_token_ids':True,'return_token_ids':True,'logprobs':20}
  response=post(request)
  targets={1,106,107,ids[index] if index<len(ids) else 1}
  for text in ['"','"}','."','.",','",',' "',' Не',' Также']:
   targets.add(tokenizer.encode(text,add_special_tokens=False)[0])
  selected=post({**request,'logprobs':len(targets),'logprob_token_ids':sorted(targets)})
  prefix=tokenizer.decode(ids[:index],skip_special_tokens=False,clean_up_tokenization_spaces=False)
  record={'case':case['id'],'sentence_index':n,'token_index':index,'prefix_tail':prefix[-350:],'template_matches':True,'raw_top':probability_rows(response,mask),'selected':probability_rows(selected,mask),'recorded_next_token':ids[index] if index<len(ids) else None,'selected_completion':response['choices'][0],'usage':response['usage']}
  print(json.dumps(record,ensure_ascii=False),flush=True)
 # A free continuation from the earliest repeated-sentence neighbourhood.
 if len(points)>1:
  index=sorted(points)[min(2,len(points)-1)]
  response=post({'model':case['model'],'prompt':prompt+ids[:index],'add_special_tokens':False,'max_tokens':192,'temperature':0,'repetition_penalty':1.0,'skip_special_tokens':False,'return_token_ids':True})
  print(json.dumps({'case':case['id'],'kind':'unconstrained_continuation','prefix_tokens':index,'response':response},ensure_ascii=False),flush=True)
