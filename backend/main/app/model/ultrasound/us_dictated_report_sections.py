from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class USDictatedReportSections:
    description: str
    conclusion: str | None = None
