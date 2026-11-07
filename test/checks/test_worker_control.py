import asyncio
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'backend'))
from model_control import ControlledModelService, take_control
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from worker_evidence import arm_worker,verify_worker


class WorkerControlTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.identity = '12345678-1234-1234-1234-123456789abc'
        self.text = '{"description":"Actual local model response","conclusion":"Actual conclusion"}'
        self.wrapped = AsyncMock()
        self.wrapped.call.return_value = self.text

    def arm(self, mode):
        (self.directory/'worker-control.json').write_text(json.dumps(dict(mode=mode, examinationNumber='REG-FAULT')))
        return ControlledModelService(self.wrapped, self.directory, 'REG-FAULT', self.identity)

    async def test_only_the_matching_job_consumes_the_failure_once(self):
        self.arm('fail-before')
        self.assertIsNone(take_control(self.directory, 'REG-OTHER', self.identity))
        self.assertTrue((self.directory/'worker-control.json').exists())
        self.assertEqual(take_control(self.directory, 'REG-FAULT', self.identity)['mode'], 'fail-before')
        self.assertIsNone(take_control(self.directory, 'REG-FAULT', self.identity))
        self.assertEqual(json.loads((self.directory/f'worker-applied-{self.identity}.json').read_text())['examinationNumber'], 'REG-FAULT')

    async def test_failure_before_output_does_not_call_the_model(self):
        model = self.arm('fail-before')
        with patch('model_control.asyncio.sleep', new=AsyncMock()):
            with self.assertRaisesRegex(RuntimeError, 'generation failure'):
                await anext(model.stream(object()))
        self.wrapped.call.assert_not_called()

    async def test_interruption_keeps_the_real_partial_text_and_does_not_complete(self):
        model = self.arm('fail-after-preview')
        stream = model.stream(object())
        partial = await anext(stream)
        self.assertTrue(self.text.startswith(partial))
        self.assertIn('Actual local model response', partial)
        self.assertNotIn('Actual conclusion', partial)
        with patch('model_control.asyncio.sleep', new=AsyncMock()):
            with self.assertRaisesRegex(RuntimeError, 'interruption'):
                await anext(stream)
        self.wrapped.call.assert_awaited_once()

    async def test_delayed_result_reassembles_the_original_json(self):
        model = self.arm('delay-completion')
        with patch('model_control.asyncio.sleep', new=AsyncMock()):
            self.assertEqual(''.join([chunk async for chunk in model.stream(object())]), self.text)

    async def test_cancellation_does_not_yield_a_late_success(self):
        stream = self.arm('delay-completion').stream(object())
        await anext(stream)
        task = asyncio.create_task(anext(stream))
        await asyncio.sleep(0)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await task
        with self.assertRaises(StopAsyncIteration):
            await anext(stream)

    async def test_unarmed_requests_delegate_original_chunks(self):
        async def chunks(_):
            yield 'one'
            yield 'two'
        self.wrapped.stream = chunks
        model = ControlledModelService(self.wrapped, self.directory, 'REG-OTHER', self.identity)
        self.assertEqual([chunk async for chunk in model.stream(object())], ['one', 'two'])
        self.wrapped.call.assert_not_called()


    async def test_receipt_must_belong_to_the_observed_job_and_exact_control(self):
        control = dict(mode="fail-before", examinationNumber="REG-RECEIPT")
        before = arm_worker(self.directory, control)
        with self.assertRaises(ValueError):
            verify_worker(self.directory, before, control, self.identity)
        take_control(self.directory, "REG-RECEIPT", self.identity)
        self.assertEqual(verify_worker(self.directory, before, control, self.identity)["control"], control)
        with self.assertRaises(ValueError):
            verify_worker(self.directory, before, {**control, "mode": "fail-after-preview"}, self.identity)
