"""Compare two Hulu runtimes and check one text report per model together."""
from __future__ import annotations

import asyncio
import hashlib
import json
import sys
import time
from pathlib import Path

import httpx

sys.path.insert(0, '/app')
from app.core.create_app import create_app
from app.model.generation_request import GenerationRequest
from app.service.vllm_service import VLLMService

OUTPUT = Path('/tmp/hulu7-joint.json')
RESPONSES = Path('/tmp/hulu7-joint-responses.json')


async def main() -> None:
    app = create_app()
    case = next(row for row in json.loads(Path('/tmp/hulu7-cases.json').read_text()) if row['name']=='report_en')
    report = {'is_complete':False,'is_memory_aborted':False,'checks':[],'memory_samples':[],'scope':'One matched English synthetic report; warm single-model samples and one report per each of five models together'}
    responses = {}
    def save():
        OUTPUT.write_text(json.dumps(report,indent=2)+'\n')
        RESPONSES.write_text(json.dumps(responses,ensure_ascii=False,indent=2)+'\n')
    async with httpx.AsyncClient() as client:
        service = VLLMService(client,app.state.variables,app.state.server_config)
        async def generate(model_id,scenario):
            request = GenerationRequest.model_validate(dict(case['request'],modelId=model_id))
            started = time.monotonic()
            first = None
            chunks = []
            async for value in service.stream(request):
                if first is None:first = time.monotonic()-started
                chunks.append(value)
            text = ''.join(chunks)
            json.loads(text)
            key = scenario+':'+model_id
            responses[key] = text
            report['checks'].append({'scenario':scenario,'model_id':model_id,'seconds':time.monotonic()-started,'first_delta_seconds':first,'delta_count':len(chunks),'response_chars':len(text),'response_sha256':hashlib.sha256(text.encode()).hexdigest(),'is_passed':True})
            save()
        async def batch(models,scenario):
            tasks = [asyncio.create_task(generate(model,scenario)) for model in models]
            try:
                while not all(task.done() for task in tasks):
                    available = next(int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemAvailable:'))
                    report['memory_samples'].append({'unix':time.time(),'available_kib':available,'scenario':scenario})
                    if available<8*1024**2:
                        report['is_memory_aborted'] = True
                        raise RuntimeError('Insufficient memory for joint synthetic test')
                    await asyncio.sleep(0.25)
                await asyncio.gather(*tasks)
            finally:
                for task in tasks:
                    if not task.done():task.cancel()
                await asyncio.gather(*tasks,return_exceptions=True)
        try:
            await batch(['ZJU-AI4H/Hulu-Med-7B'],'isolated_7b')
            await batch(['ZJU-AI4H/Hulu-Med-32B'],'isolated_32b')
            assert len(service.model_ids)==5
            await batch(service.model_ids,'all_five')
            report['minimum_available_gib'] = min(row['available_kib'] for row in report['memory_samples'])/1024**2
            report['is_complete'] = True
        except BaseException as error:
            report['error_type'] = type(error).__name__
            raise
        finally:
            save()


if __name__ == '__main__':
    asyncio.run(main())
