from __future__ import annotations

from pydantic import BaseModel


class USExaminationScanPhoto(BaseModel):
    data: str
