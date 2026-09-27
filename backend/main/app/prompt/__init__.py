from __future__ import annotations

from app.core.language_code import LanguageCode
from app.prompt.base import PromptFactory
from app.prompt.en import PromptFactoryEn
from app.prompt.ru import PromptFactoryRu

_FACTORIES: dict[LanguageCode, PromptFactory] = {
    LanguageCode.EN: PromptFactoryEn(),
    LanguageCode.RU: PromptFactoryRu(),
}


def resolve_prompt_factory(language_code: LanguageCode) -> PromptFactory:
    return _FACTORIES[language_code]
