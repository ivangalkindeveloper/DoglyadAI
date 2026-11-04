from __future__ import annotations

from enum import StrEnum


class USReportGenerationStatus(StrEnum):
    QUEUED = "queued"
    GENERATING = "generating"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

    @property
    def is_terminal(
        self,
    ) -> bool:
        return self in (self.COMPLETED, self.FAILED, self.CANCELLED)
