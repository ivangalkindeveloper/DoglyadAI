"""One-shot generation faults for the isolated regression worker, never for billing."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
import re

MODES = {"fail-before", "fail-after-preview", "delay-completion"}


def take_control(directory: Path, examination_number: str, generation_id: str) -> dict | None:
    path = directory / "worker-control.json"
    if not path.exists():
        return None
    control = json.loads(path.read_text())
    if control.get("examinationNumber") != examination_number:
        return None
    if (
        control.get("mode") not in MODES
        or not re.fullmatch(r"REG-[A-Z0-9-]+", examination_number)
        or not re.fullmatch(r"[a-fA-F0-9-]{36}", generation_id)
    ):
        raise ValueError("Invalid regression worker control")
    destination = directory / ("worker-applied-" + generation_id + ".json")
    path.rename(destination)
    return control


class ControlledModelService:
    def __init__(self, wrapped, directory: Path, examination_number: str, generation_id: str):
        self.wrapped = wrapped
        self.directory = directory
        self.examination_number = examination_number
        self.generation_id = generation_id

    async def call(self, request):
        return await self.wrapped.call(request)

    async def stream(self, request):
        control = take_control(self.directory, self.examination_number, self.generation_id)
        if control is None:
            async for chunk in self.wrapped.stream(request):
                yield chunk
            return
        mode = control["mode"]
        if mode == "fail-before":
            await asyncio.sleep(1)
            raise RuntimeError("Controlled regression generation failure")
        text = await self.wrapped.call(request)
        # The actual mock response starts with description. Publish that section, not fabricated text.
        boundary = text.find('"conclusion"')
        if boundary <= 0:
            raise ValueError("Mock report no longer contains the expected description/conclusion order")
        yield text[:boundary]
        await asyncio.sleep(5 if mode == "fail-after-preview" else 30)
        if mode == "fail-after-preview":
            raise RuntimeError("Controlled regression interruption after a preview")
        yield text[boundary:]
