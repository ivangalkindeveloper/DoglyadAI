from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.ready_made_template_list_config import ReadyMadeTemplateListConfig
from app.model.scan_config import ScanConfig
from app.model.scan_speech_config import ScanSpeechConfig
from app.model.settings_ai_config import SettingsAIConfig
from app.model.template_add_config import TemplateAddConfig
from app.model.template_edit_config import TemplateEditConfig
from app.model.user_settings_config import UserSettingsConfig


class ApplicationModuleConfig(BaseModel):
    """Typed module sections of application.json; the full document stays unmodeled."""

    model_config = ConfigDict(
        extra="ignore",
        frozen=True,
    )

    scan: ScanConfig
    scanSpeech: ScanSpeechConfig
    templateAdd: TemplateAddConfig
    templateEdit: TemplateEditConfig
    readyMadeTemplateList: ReadyMadeTemplateListConfig
    userSettings: UserSettingsConfig
    settingsAI: SettingsAIConfig
