# UserSettings

Исходники: [ios/Doglyad/Application/Module/UserSettings](../../../ios/Doglyad/Application/Module/UserSettings).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `UserSettings.email` | Рабочая почта сохраняется | maestro |
| `UserSettings.flags` | Все три переключателя | maestro |
| `UserSettings.validation-cancel-failure` | Валидация почты, отмена и ошибка записи | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
