from __future__ import annotations

from pydantic import BaseModel


class USExaminationType(BaseModel):
    id: str
    title: dict[str, str]

    def get_localized_title(self, language_code: str) -> str:
        return self.title.get(language_code) or next(iter(self.title.values()), "")
