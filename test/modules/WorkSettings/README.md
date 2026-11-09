# WorkSettings

Исходники: [ios/Doglyad/Application/Module/WorkSettings](../../../ios/Doglyad/Application/Module/WorkSettings).

Сценарии и ожидаемые результаты: [cases.yaml](cases.yaml). `e2e/` содержит исполняемые Maestro-файлы, `atlas/` — только снимки Preview.

| ID | Сценарий | Автоматизация |
|---|---|---|
| `WorkSettings.patient-consent` | Включить и выключить запрос согласия пациента | mixed |
| `WorkSettings.email` | Рабочая почта сохраняется | maestro |
| `WorkSettings.flags` | Все три переключателя | maestro |
| `WorkSettings.validation-cancel-failure` | Валидация почты, отмена и ошибка записи | maestro |

Сначала выполните предусловия сценария. Каждый шаг содержит действие и наблюдаемый результат. Не считайте наличие YAML или Preview успешным прохождением.
