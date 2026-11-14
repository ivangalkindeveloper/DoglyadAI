"""Check the deployed transport using synthetic inputs; never log request content."""
from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import struct
import sys
import time
import zlib
from pathlib import Path

import httpx
sys.path.insert(0, '/app')
from app.core.create_app import create_app
from app.model.generation_request import GenerationRequest
from app.service.vllm_service import VLLMService

MODEL = 'ZJU-AI4H/Hulu-Med-7B'
OUTPUT = Path('/tmp/hulu7-validation.json')
RESPONSES = Path('/tmp/hulu7-responses.json')


def picture(rgb, side, height=None):
    height = side if height is None else height
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    square = min(side, height) * 165 // 224
    left, top = (side - square) // 2, (height - square) // 2
    raw = b''.join(b'\0' + b''.join(bytes(rgb if left <= x <= left + square and top <= y <= top + square else (255,255,255)) for x in range(side)) for y in range(height))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', side, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
    return base64.b64encode(png).decode()


def _has_expected_language(value, language):
    def strings(item):
        if isinstance(item, str):
            return [item]
        if isinstance(item, dict):
            return [text for child in item.values() for text in strings(child)]
        if isinstance(item, list):
            return [text for child in item for text in strings(child)]
        return []
    text = ' '.join(strings(value))
    import re
    cyrillic = len(re.findall('[А-Яа-яЁё]', text))
    latin = len(re.findall('[A-Za-z]', text))
    return cyrillic > 20 and cyrillic > latin if language == 'ru' else latin > 20 and latin > cyrillic


async def main():
    app = create_app()
    report = {'is_complete': False, 'model_id': MODEL, 'checks': [], 'scope': 'VLLMService transport inside the deployed backend; public App Check checked separately'}
    responses = {}
    def save():
        OUTPUT.write_text(json.dumps(report, indent=2) + '\n')
        RESPONSES.write_text(json.dumps(responses, ensure_ascii=False, indent=2) + '\n')
    try:
        async with httpx.AsyncClient() as client:
            service = VLLMService(client, app.state.variables, app.state.server_config)
            assert MODEL in service.model_ids
            report['configured_model_ids'] = service.model_ids
            async def check(name, request, *, is_stream=False, expected=None):
                started = time.monotonic()
                first = None
                chunks = []
                if is_stream:
                    async for value in service.stream(request):
                        if first is None:
                            first = time.monotonic() - started
                        chunks.append(value)
                    text = ''.join(chunks)
                else:
                    text = await service.generate(request)
                result = json.loads(text) if request.structuredOutput else text.strip()
                passed = expected(result) if expected else bool(result)
                row = {'name': name, 'seconds': time.monotonic() - started, 'first_delta_seconds': first, 'delta_count': len(chunks), 'response_chars': len(text), 'response_sha256': hashlib.sha256(text.encode()).hexdigest(), 'is_passed': passed}
                report['checks'].append(row)
                if name.startswith('report_'):
                    responses[name] = text
                save()
                assert passed, 'Synthetic output check failed: ' + name
                return row
            await check('plain_text', GenerationRequest(modelId=MODEL, prompt='What is 2 + 2? Answer with the number only.', temperature=0, maxTokens=32), expected=lambda value: value == '4')
            schema = json.dumps({'type': 'object', 'properties': {'answer': {'type': 'integer'}}, 'required': ['answer'], 'additionalProperties': False})
            await check('structured_json', GenerationRequest(modelId=MODEL, prompt='What is 2 + 2? Put the result in answer.', temperature=0, maxTokens=64, structuredOutput=schema), expected=lambda value: value == {'answer': 4})
            cases = json.loads(Path('/tmp/hulu7-cases.json').read_text())
            for case in cases:
                await check(case['name'], GenerationRequest.model_validate(case['request']), is_stream=True, expected=lambda value, language=case['name'][-2:]: _has_expected_language(value, language))
            color_schema = json.dumps({'type':'object','properties':{'color':{'type':'string'}},'required':['color'],'additionalProperties':False})
            await check('image', GenerationRequest(modelId=MODEL, prompt='What color is the large square? Answer with the lowercase English color name in color.', images=[{'data':picture((255,0,0),224)}], temperature=0, maxTokens=64, structuredOutput=color_schema), expected=lambda value: value['color'].strip().lower() == 'red')
            await check('image_1024x768', GenerationRequest(modelId=MODEL, prompt='What color is the large square? Answer with the lowercase English color name in color.', images=[{'data':picture((255,0,0),1024,768)}], temperature=0, maxTokens=64, structuredOutput=color_schema), expected=lambda value: value['color'].strip().lower() == 'red')
            await check('image_4032x3024', GenerationRequest(modelId=MODEL, prompt='What color is the large square? Answer with the lowercase English color name in color.', images=[{'data':picture((255,0,0),4032,3024)}], temperature=0, maxTokens=64, structuredOutput=color_schema), expected=lambda value: value['color'].strip().lower() == 'red')
            expected_colors = ['red','green','blue','red','green','blue']
            array_schema = json.dumps({'type':'object','properties':{'colors':{'type':'array','items':{'type':'string'},'minItems':6,'maxItems':6}},'required':['colors'],'additionalProperties':False})
            await check('six_images', GenerationRequest(modelId=MODEL, prompt='List the colors of the large squares in the six images, in their original order. Use lowercase English color names in colors.', images=[{'data':picture(rgb,448)} for rgb in [(255,0,0),(0,255,0),(0,0,255)]*2], temperature=0, maxTokens=128, structuredOutput=array_schema), expected=lambda value: [x.strip().lower() for x in value['colors']] == expected_colors)
            started = time.monotonic()
            await asyncio.gather(*(check(f'parallel_{index+1}', GenerationRequest(modelId=MODEL,prompt=f'Compute {index} + 1. Answer with the number only.',temperature=0,maxTokens=32), expected=lambda value, number=index+1: value == str(number)) for index in range(8)))
            report['parallel_batch_seconds'] = time.monotonic() - started
            report['is_complete'] = True
    except Exception as error:
        report['error'] = {'type': type(error).__name__}
        raise
    finally:
        save()


if __name__ == '__main__':
    asyncio.run(main())
