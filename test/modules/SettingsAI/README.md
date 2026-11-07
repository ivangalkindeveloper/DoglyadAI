# SettingsAI

Исходники: [ios/Doglyad/Application/Module/Settings/SettingsAI](../../../ios/Doglyad/Application/Module/Settings/SettingsAI).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `SettingsAI.choices` | Выбор транскрибатора, парсера и модели | mixed |
| `SettingsAI.generation-settings` | Markdown, температура и токены | maestro |
| `SettingsAI.limits` | Границы температуры и токенов | mixed |
| `SettingsAI.base-gate` | Ограничения Base и смена подписки | mixed |
| `SettingsAI.save-failure` | Ошибка сохранения AI-настроек | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
